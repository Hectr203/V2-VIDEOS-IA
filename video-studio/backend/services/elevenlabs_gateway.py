"""
Gateway resiliente de rotación de cuentas y catálogo dinámico de voces para ElevenLabs.

Arquitectura de almacenamiento elegida:
- Las múltiples API keys viven en `video-studio/backend/.env` (archivo ignorado por Git) usando
  variables indexadas `ELEVENLABS_API_KEY_1` .. `ELEVENLABS_API_KEY_N` (ej. 6 cuentas), con soporte
  retrocompatible para `ELEVENLABS_API_KEYS` (separadas por coma) y `ELEVENLABS_API_KEY` (clave única).
- Motivo: mantiene un único punto de configuración seguro protegido por `.gitignore`, permite activar,
  pausar o rotar cualquier cuenta comentando una sola línea y facilita la adopción por terceros vía
  `.env.example` sin crear carpetas adicionales con secretos dispersos.
- Seguridad: nunca expone claves reales en logs, respuestas HTTP ni excepciones; cada cuenta se reporta
  únicamente por su etiqueta (`cuenta_1`, `cuenta_2`, ...) y sufijo enmascarado (`***abcd`).
"""

from __future__ import annotations

import base64
import json
import os
import re
import threading
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


API_BASE_URL = "https://api.elevenlabs.io/v1"
DEFAULT_MIN_CREDITS_THRESHOLD = 500
DEFAULT_MODEL_ID = "eleven_flash_v2_5"
DEFAULT_TIMEOUT_SECONDS = 30
SUBSCRIPTION_CACHE_TTL_SECONDS = 60.0
TRANSIENT_COOLDOWN_SECONDS = 120.0
EXHAUSTED_COOLDOWN_SECONDS = 900.0

GENDER_ES = {
    "male": "Masculino",
    "female": "Femenino",
    "neutral": "Neutro",
}

AGE_ES = {
    "young": "Joven",
    "middle_aged": "Adulto",
    "middle aged": "Adulto",
    "old": "Mayor",
}


def load_backend_env(env_file: Optional[Path] = None, override: bool = False) -> Optional[Path]:
    """Carga variables desde `video-studio/backend/.env` sin sobrescribir entorno existente salvo override."""
    target = env_file or (Path(__file__).resolve().parents[1] / ".env")
    if not target.is_file():
        return None
    for raw_line in target.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip("\"'")
        if not key:
            continue
        if override or key not in os.environ:
            os.environ[key] = value
    return target


def mask_api_key(api_key: str) -> str:
    """Devuelve una huella segura de la clave sin exponer el secreto."""
    clean = (api_key or "").strip()
    if len(clean) <= 6:
        return "***"
    return f"{clean[:3]}...{clean[-4:]}"


def _parse_int_env(name: str, default: int) -> int:
    raw = os.getenv(name, "").strip()
    if not raw:
        return default
    try:
        val = int(raw)
        return val if val >= 0 else default
    except ValueError:
        return default


def collect_elevenlabs_keys(env: Optional[Dict[str, str]] = None) -> List[Tuple[str, str]]:
    """
    Recolecta claves configuradas preservando orden determinista y sin duplicados:
    1. `ELEVENLABS_API_KEY_1`, `ELEVENLABS_API_KEY_2`, ... (orden numérico ascendente)
    2. `ELEVENLABS_API_KEYS` (separadas por coma o salto de línea)
    3. `ELEVENLABS_API_KEY` (clave única heredada; retrocompatible)
    """
    source = env if env is not None else dict(os.environ)
    collected: List[Tuple[str, str]] = []
    seen_keys: set[str] = set()
    used_labels: set[str] = set()

    def _next_label() -> str:
        idx = 1
        while f"cuenta_{idx}" in used_labels:
            idx += 1
        return f"cuenta_{idx}"

    def _add(label: Optional[str], raw_key: str) -> None:
        clean = (raw_key or "").strip().strip("\"'")
        if not clean or clean.lower().startswith(("tu_api_key", "your_api_key", "sk_ejemplo")):
            return
        if clean in seen_keys:
            return
        final_label = label if (label and label not in used_labels) else _next_label()
        seen_keys.add(clean)
        used_labels.add(final_label)
        collected.append((final_label, clean))

    # 1. Variables indexadas ELEVENLABS_API_KEY_1..N
    indexed: List[Tuple[int, str, str]] = []
    for k, v in source.items():
        m = re.fullmatch(r"ELEVENLABS_API_KEY_(\d+)", k)
        if m:
            indexed.append((int(m.group(1)), k, v))
    for num, _, val in sorted(indexed, key=lambda item: item[0]):
        _add(f"cuenta_{num}", val)

    # 2. Lista separada por comas ELEVENLABS_API_KEYS
    raw_list = source.get("ELEVENLABS_API_KEYS", "")
    if raw_list.strip():
        parts = [p.strip() for p in re.split(r"[,\n;]+", raw_list) if p.strip()]
        for part in parts:
            _add(None, part)

    # 3. Clave heredada ELEVENLABS_API_KEY
    legacy = source.get("ELEVENLABS_API_KEY", "")
    if legacy.strip():
        _add(None, legacy)

    return collected


@dataclass
class AccountState:
    label: str
    api_key: str
    masked_key: str
    status: str = "unknown"  # active, low_quota, exhausted, invalid_key, rate_limited, network_error, unknown
    tier: str = ""
    character_count: Optional[int] = None
    character_limit: Optional[int] = None
    remaining_characters: Optional[int] = None
    last_checked: float = 0.0
    cooldown_until: float = 0.0
    last_error: str = ""

    def to_public_dict(self, min_threshold: int) -> Dict[str, Any]:
        """Representación segura para API/CLI sin exponer jamás la API key."""
        now = time.time()
        in_cooldown = self.cooldown_until > now
        return {
            "account": self.label,
            "key_hint": self.masked_key,
            "status": self.status,
            "tier": self.tier or "desconocido",
            "character_count": self.character_count,
            "character_limit": self.character_limit,
            "remaining_characters": self.remaining_characters,
            "meets_threshold": (
                self.remaining_characters is not None
                and self.remaining_characters >= min_threshold
                and self.status == "active"
                and not in_cooldown
            ),
            "in_cooldown": in_cooldown,
            "cooldown_seconds_left": max(0, int(self.cooldown_until - now)) if in_cooldown else 0,
            "last_error": self.last_error or None,
        }


def _http_json_request(
    url: str,
    api_key: str,
    method: str = "GET",
    payload: Optional[Dict[str, Any]] = None,
    timeout: int = DEFAULT_TIMEOUT_SECONDS,
) -> Tuple[int, Dict[str, Any]]:
    """Ejecuta una llamada JSON contra ElevenLabs devolviendo (status_code, body_dict)."""
    headers = {
        "xi-api-key": api_key,
        "Accept": "application/json",
    }
    data_bytes = None
    if payload is not None:
        headers["Content-Type"] = "application/json"
        data_bytes = json.dumps(payload).encode("utf-8")

    req = urllib.request.Request(url, data=data_bytes, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8")
            return resp.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        body_raw = ""
        try:
            body_raw = exc.read().decode("utf-8", errors="ignore")
        except Exception:
            pass
        try:
            parsed = json.loads(body_raw) if body_raw else {}
        except json.JSONDecodeError:
            parsed = {"detail": body_raw[:250]}
        return exc.code, parsed


class ElevenLabsGateway:
    """
    Gateway con health-check, verificación de cuota real (`/v1/user/subscription`),
    rotación automática entre múltiples cuentas y catálogo enriquecido de voces (`/v1/voices`).
    """

    def __init__(
        self,
        keys: Optional[List[Tuple[str, str]]] = None,
        min_credits_threshold: Optional[int] = None,
        default_model: Optional[str] = None,
        timeout: Optional[int] = None,
        request_fn=None,
    ) -> None:
        load_backend_env()
        raw_keys = keys if keys is not None else collect_elevenlabs_keys()
        self.min_credits_threshold = (
            min_credits_threshold
            if min_credits_threshold is not None
            else _parse_int_env("ELEVENLABS_MIN_CREDITS_THRESHOLD", DEFAULT_MIN_CREDITS_THRESHOLD)
        )
        self.default_model = (
            default_model
            or os.getenv("ELEVENLABS_DEFAULT_MODEL", DEFAULT_MODEL_ID).strip()
            or DEFAULT_MODEL_ID
        )
        self.timeout = (
            timeout
            if timeout is not None
            else _parse_int_env("ELEVENLABS_REQUEST_TIMEOUT", DEFAULT_TIMEOUT_SECONDS)
        )
        self._request_fn = request_fn or _http_json_request
        self._lock = threading.RLock()
        self._accounts: List[AccountState] = [
            AccountState(label=label, api_key=key, masked_key=mask_api_key(key))
            for label, key in raw_keys
        ]
        self._active_index: int = 0

    @property
    def configured_count(self) -> int:
        return len(self._accounts)

    def has_keys(self) -> bool:
        return len(self._accounts) > 0

    def reload_from_env(self) -> int:
        """Recarga claves desde `.env` y entorno preservando el estado de cuentas ya conocidas."""
        with self._lock:
            load_backend_env(override=False)
            prev_by_key = {acc.api_key: acc for acc in self._accounts}
            fresh = collect_elevenlabs_keys()
            new_accounts: List[AccountState] = []
            for label, key in fresh:
                if key in prev_by_key:
                    acc = prev_by_key[key]
                    acc.label = label
                    new_accounts.append(acc)
                else:
                    new_accounts.append(AccountState(label=label, api_key=key, masked_key=mask_api_key(key)))
            self._accounts = new_accounts
            if self._active_index >= len(self._accounts):
                self._active_index = 0
            return len(self._accounts)

    def _ordered_indices(self) -> List[int]:
        n = len(self._accounts)
        if n == 0:
            return []
        start = self._active_index % n
        return [(start + offset) % n for offset in range(n)]

    def _extract_error_detail(self, body: Dict[str, Any], status_code: int) -> str:
        detail = body.get("detail")
        if isinstance(detail, dict):
            msg = detail.get("message") or detail.get("status") or str(detail)
        elif detail:
            msg = str(detail)
        else:
            msg = f"HTTP {status_code}"
        return msg[:220]

    def check_account_health(self, account: AccountState, force: bool = False) -> AccountState:
        """Verifica conectividad y saldo real en `/v1/user/subscription` para una cuenta."""
        now = time.time()
        if not force and account.last_checked and (now - account.last_checked) < SUBSCRIPTION_CACHE_TTL_SECONDS:
            return account

        try:
            status_code, body = self._request_fn(
                f"{API_BASE_URL}/user/subscription",
                account.api_key,
                method="GET",
                payload=None,
                timeout=self.timeout,
            )
        except Exception as exc:
            account.status = "network_error"
            account.last_error = f"Error de conexión con ElevenLabs: {type(exc).__name__}"
            account.last_checked = now
            account.cooldown_until = now + TRANSIENT_COOLDOWN_SECONDS
            return account

        account.last_checked = now
        if status_code == 200:
            count = int(body.get("character_count", 0) or 0)
            limit = int(body.get("character_limit", 0) or 0)
            remaining = max(0, limit - count)
            account.tier = str(body.get("tier") or "free")
            account.character_count = count
            account.character_limit = limit
            account.remaining_characters = remaining
            account.last_error = ""
            if remaining <= 0:
                account.status = "exhausted"
                account.cooldown_until = now + EXHAUSTED_COOLDOWN_SECONDS
            elif remaining < self.min_credits_threshold:
                account.status = "low_quota"
                account.cooldown_until = 0.0
            else:
                account.status = "active"
                account.cooldown_until = 0.0
            return account

        detail = self._extract_error_detail(body, status_code)
        account.last_error = detail
        if status_code == 401:
            account.status = "invalid_key"
            account.cooldown_until = now + EXHAUSTED_COOLDOWN_SECONDS
        elif status_code in (402, 429) or "quota" in detail.lower() or "credit" in detail.lower():
            account.status = "exhausted" if status_code == 402 or "quota" in detail.lower() else "rate_limited"
            account.cooldown_until = now + (EXHAUSTED_COOLDOWN_SECONDS if account.status == "exhausted" else TRANSIENT_COOLDOWN_SECONDS)
        else:
            account.status = "network_error"
            account.cooldown_until = now + TRANSIENT_COOLDOWN_SECONDS
        return account

    def get_pool_status(self, force_refresh: bool = True) -> Dict[str, Any]:
        """Consulta y devuelve el estado consolidado de todas las cuentas sin exponer secretos."""
        with self._lock:
            if not self._accounts:
                return {
                    "configured": False,
                    "service_healthy": False,
                    "total_accounts": 0,
                    "available_accounts": 0,
                    "total_remaining_characters": 0,
                    "min_credits_threshold": self.min_credits_threshold,
                    "default_model": self.default_model,
                    "active_account": None,
                    "accounts": [],
                }

            for acc in self._accounts:
                self.check_account_health(acc, force=force_refresh)

            public_accounts = [acc.to_public_dict(self.min_credits_threshold) for acc in self._accounts]
            available = [a for a in public_accounts if a["meets_threshold"]]
            total_remaining = sum(
                acc.remaining_characters for acc in self._accounts if acc.remaining_characters is not None
            )
            active_label = None
            for idx in self._ordered_indices():
                if self._accounts[idx].to_public_dict(self.min_credits_threshold)["meets_threshold"]:
                    self._active_index = idx
                    active_label = self._accounts[idx].label
                    break

            return {
                "configured": True,
                "service_healthy": len(available) > 0,
                "total_accounts": len(self._accounts),
                "available_accounts": len(available),
                "total_remaining_characters": total_remaining,
                "min_credits_threshold": self.min_credits_threshold,
                "default_model": self.default_model,
                "active_account": active_label,
                "accounts": public_accounts,
            }

    def select_healthy_account(self, required_characters: int = 0, force_refresh: bool = False) -> AccountState:
        """
        Selecciona la mejor cuenta sana con saldo suficiente (`>= max(umbral, required_characters)`).
        Si la cuenta actual está agotada o por debajo del umbral, rota automáticamente a la siguiente.
        """
        with self._lock:
            if not self._accounts:
                raise RuntimeError(
                    "No hay API keys de ElevenLabs configuradas. Configura ELEVENLABS_API_KEY_1..6 o ELEVENLABS_API_KEY en video-studio/backend/.env"
                )

            min_needed = max(self.min_credits_threshold, required_characters)
            now = time.time()
            fallback_candidate: Optional[Tuple[int, AccountState]] = None

            for idx in self._ordered_indices():
                acc = self._accounts[idx]
                if acc.cooldown_until > now and not force_refresh:
                    continue
                self.check_account_health(acc, force=force_refresh)
                rem = acc.remaining_characters if acc.remaining_characters is not None else -1
                if acc.status == "active" and rem >= min_needed:
                    self._active_index = idx
                    return acc
                # Si tiene menos del umbral de seguridad pero aún le alcanza estrictamente para este texto,
                # guardarla como último recurso si no hay ninguna otra cuenta con saldo holgado.
                if acc.status in ("active", "low_quota") and required_characters > 0 and rem >= required_characters:
                    if fallback_candidate is None or rem > (fallback_candidate[1].remaining_characters or 0):
                        fallback_candidate = (idx, acc)

            if fallback_candidate is not None:
                self._active_index = fallback_candidate[0]
                return fallback_candidate[1]

            summary = ", ".join(
                f"{acc.label}:{acc.status}({acc.remaining_characters if acc.remaining_characters is not None else 'n/a'})"
                for acc in self._accounts
            )
            raise RuntimeError(
                f"Ninguna cuenta de ElevenLabs tiene saldo suficiente (requerido>={min_needed} chars). Estado del pool: {summary}"
            )

    def _format_voice(self, voice: Dict[str, Any]) -> Dict[str, Any]:
        labels = voice.get("labels") or {}
        raw_gender = str(labels.get("gender") or "unknown").strip().lower()
        raw_age = str(labels.get("age") or "unknown").strip().lower()
        accent = str(labels.get("accent") or "").strip()
        descriptive = str(labels.get("descriptive") or labels.get("description") or "").strip()
        use_case = str(labels.get("use_case") or labels.get("use case") or "").strip()
        category = str(voice.get("category") or "premade").strip()
        name = str(voice.get("name") or voice.get("voice_id") or "").strip()

        gender_es = GENDER_ES.get(raw_gender, raw_gender.title() if raw_gender != "unknown" else "Sin especificar")
        age_es = AGE_ES.get(raw_age, raw_age.replace("_", " ").title() if raw_age != "unknown" else "Sin especificar")

        tags = [p for p in (gender_es, age_es, accent.title() if accent else "", descriptive.title() if descriptive else "") if p and p != "Sin especificar"]
        display_label = f"{name} ({' · '.join(tags)})" if tags else name

        return {
            "id": voice["voice_id"],
            "name": name,
            "display_label": display_label,
            "gender": gender_es,
            "gender_raw": raw_gender,
            "age": age_es,
            "age_raw": raw_age.replace(" ", "_"),
            "accent": accent or "neutral",
            "style": descriptive or use_case or "general",
            "use_case": use_case or "narration",
            "category": category,
            "description": str(voice.get("description") or "").strip(),
            "preview_url": voice.get("preview_url") or None,
        }

    def list_voices(
        self,
        age: Optional[str] = None,
        gender: Optional[str] = None,
        search: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Consulta `/v1/voices` usando la primera cuenta operativa del pool (con failover automático)
        y devuelve el catálogo enriquecido con género, edad, acento, estilo y preview_url.
        """
        with self._lock:
            if not self._accounts:
                raise RuntimeError(
                    "No hay API keys de ElevenLabs configuradas en video-studio/backend/.env"
                )

            last_err = "Sin cuentas disponibles"
            chosen_label = None
            raw_voices: List[Dict[str, Any]] = []

            for idx in self._ordered_indices():
                acc = self._accounts[idx]
                try:
                    status_code, body = self._request_fn(
                        f"{API_BASE_URL}/voices",
                        acc.api_key,
                        method="GET",
                        payload=None,
                        timeout=self.timeout,
                    )
                except Exception as exc:
                    acc.status = "network_error"
                    acc.last_error = type(exc).__name__
                    last_err = f"{acc.label}: {type(exc).__name__}"
                    continue

                if status_code == 200:
                    raw_voices = [v for v in body.get("voices", []) if v.get("voice_id")]
                    chosen_label = acc.label
                    break

                detail = self._extract_error_detail(body, status_code)
                acc.last_error = detail
                if status_code == 401:
                    acc.status = "invalid_key"
                    acc.cooldown_until = time.time() + EXHAUSTED_COOLDOWN_SECONDS
                last_err = f"{acc.label}: {detail}"

            if chosen_label is None:
                raise RuntimeError(f"No se pudo consultar el catálogo de voces de ElevenLabs ({last_err})")

            voices = [self._format_voice(v) for v in raw_voices]

            # Filtros opcionales amigables (aceptan español e inglés)
            if age:
                age_q = age.strip().lower()
                age_map = {"joven": "young", "adulto": "middle_aged", "adulta": "middle_aged", "mayor": "old"}
                norm_age = age_map.get(age_q, age_q)
                voices = [v for v in voices if norm_age in v["age_raw"] or age_q in v["age"].lower()]

            if gender:
                gen_q = gender.strip().lower()
                gen_map = {"masculino": "male", "hombre": "male", "femenino": "female", "mujer": "female"}
                norm_gen = gen_map.get(gen_q, gen_q)
                voices = [v for v in voices if v["gender_raw"] == norm_gen or gen_q in v["gender"].lower()]

            if search:
                q = search.strip().lower()
                voices = [
                    v for v in voices
                    if q in v["name"].lower()
                    or q in v["style"].lower()
                    or q in v["use_case"].lower()
                    or q in v["accent"].lower()
                    or q in v["description"].lower()
                    or q in v["age"].lower()
                ]

            voices.sort(key=lambda v: (0 if v["age_raw"] == "young" else 1, v["name"].lower()))
            return {
                "account_used": chosen_label,
                "total": len(voices),
                "voices": voices,
            }

    def synthesize_with_failover(
        self,
        text: str,
        voice_id: str,
        model_id: Optional[str] = None,
        voice_settings: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Sintetiza audio con timestamps (`/v1/text-to-speech/{voice_id}/with-timestamps`) rotando
        automáticamente entre cuentas cuando una está por debajo del umbral, agotada o falla en ejecución.
        """
        if not voice_id or len(voice_id.strip()) < 10:
            raise ValueError("Selecciona una voz válida de ElevenLabs desde el catálogo")
        if not text or not text.strip():
            raise ValueError("El texto a sintetizar no puede estar vacío")

        required_chars = len(text)
        chosen_model = model_id or self.default_model
        settings = voice_settings or {"stability": 0.5, "similarity_boost": 0.8}
        url = f"{API_BASE_URL}/text-to-speech/{voice_id.strip()}/with-timestamps"
        payload = {
            "text": text,
            "model_id": chosen_model,
            "voice_settings": settings,
        }

        with self._lock:
            if not self._accounts:
                raise RuntimeError(
                    "No hay API keys de ElevenLabs configuradas en video-studio/backend/.env"
                )

            # Validar previamente salud y elegir orden empezando por la cuenta recomendada
            rotations: List[str] = []
            try:
                preferred = self.select_healthy_account(required_characters=required_chars, force_refresh=False)
                preferred_idx = self._accounts.index(preferred)
                self._active_index = preferred_idx
            except RuntimeError:
                # Reintentar refrescando caché por si alguna cuenta renovó cuota
                preferred = self.select_healthy_account(required_characters=required_chars, force_refresh=True)
                self._active_index = self._accounts.index(preferred)

            errors: List[str] = []
            for idx in self._ordered_indices():
                acc = self._accounts[idx]
                now = time.time()
                if acc.cooldown_until > now:
                    continue

                # Comprobar saldo si aún no se verificó o está obsoleto
                self.check_account_health(acc, force=False)
                if acc.status in ("invalid_key", "exhausted"):
                    errors.append(f"{acc.label}:{acc.status}")
                    continue
                if acc.remaining_characters is not None and acc.remaining_characters < required_chars:
                    acc.status = "low_quota" if acc.remaining_characters > 0 else "exhausted"
                    errors.append(f"{acc.label}:saldo_insuficiente({acc.remaining_characters})")
                    rotations.append(f"{acc.label}->siguiente(saldo={acc.remaining_characters})")
                    continue

                try:
                    status_code, body = self._request_fn(
                        url,
                        acc.api_key,
                        method="POST",
                        payload=payload,
                        timeout=max(self.timeout, 40),
                    )
                except Exception as exc:
                    acc.status = "network_error"
                    acc.last_error = type(exc).__name__
                    acc.cooldown_until = time.time() + TRANSIENT_COOLDOWN_SECONDS
                    errors.append(f"{acc.label}:{type(exc).__name__}")
                    rotations.append(f"{acc.label}->siguiente(red)")
                    continue

                if status_code == 200 and body.get("audio_base64"):
                    self._active_index = idx
                    # Actualizar estimación local de saldo inmediatamente para no esperar al TTL
                    if acc.remaining_characters is not None:
                        acc.remaining_characters = max(0, acc.remaining_characters - required_chars)
                        if acc.character_count is not None:
                            acc.character_count += required_chars
                        if acc.remaining_characters <= 0:
                            acc.status = "exhausted"
                            acc.cooldown_until = time.time() + EXHAUSTED_COOLDOWN_SECONDS
                        elif acc.remaining_characters < self.min_credits_threshold:
                            acc.status = "low_quota"

                    return {
                        "audio_bytes": base64.b64decode(body["audio_base64"]),
                        "alignment": body.get("alignment", {}),
                        "model_id": chosen_model,
                        "account_used": acc.label,
                        "key_hint": acc.masked_key,
                        "remaining_characters_estimate": acc.remaining_characters,
                        "rotations": rotations,
                    }

                detail = self._extract_error_detail(body, status_code)
                acc.last_error = detail
                if status_code == 401:
                    acc.status = "invalid_key"
                    acc.cooldown_until = time.time() + EXHAUSTED_COOLDOWN_SECONDS
                elif status_code in (402, 429) or "quota" in detail.lower() or "credit" in detail.lower():
                    acc.status = "exhausted" if status_code == 402 or "quota" in detail.lower() else "rate_limited"
                    acc.cooldown_until = time.time() + (
                        EXHAUSTED_COOLDOWN_SECONDS if acc.status == "exhausted" else TRANSIENT_COOLDOWN_SECONDS
                    )
                elif status_code >= 500:
                    acc.status = "network_error"
                    acc.cooldown_until = time.time() + TRANSIENT_COOLDOWN_SECONDS
                else:
                    # Error 4xx del propio request (ej. voice_id inexistente) -> no rotar infinitamente
                    raise RuntimeError(f"ElevenLabs rechazó la solicitud ({status_code}): {detail}")

                errors.append(f"{acc.label}:HTTP_{status_code}({detail})")
                rotations.append(f"{acc.label}->siguiente(HTTP_{status_code})")

            raise RuntimeError(
                f"Todas las cuentas de ElevenLabs fallaron o agotaron cuota. Resumen: {'; '.join(errors)}"
            )


# Instancia compartida del gateway en el backend
_GLOBAL_GATEWAY: Optional[ElevenLabsGateway] = None
_GLOBAL_LOCK = threading.Lock()


def get_elevenlabs_gateway() -> ElevenLabsGateway:
    global _GLOBAL_GATEWAY
    with _GLOBAL_LOCK:
        if _GLOBAL_GATEWAY is None:
            _GLOBAL_GATEWAY = ElevenLabsGateway()
        return _GLOBAL_GATEWAY


def reset_elevenlabs_gateway() -> None:
    """Reinicia el singleton (útil para pruebas unitarias y recarga de entorno)."""
    global _GLOBAL_GATEWAY
    with _GLOBAL_LOCK:
        _GLOBAL_GATEWAY = None
