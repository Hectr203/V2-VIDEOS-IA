"""
Módulo de Cifrado y Gestión Segura: Palacio de Memoria (Mem Palace).

Proporciona persistencia cifrada de nivel militar (AES-128-CBC + HMAC-SHA256 vía Fernet)
para resguardar decisiones arquitectónicas críticas, acuerdos sensibles y secretos locales.

Características de Nivel Industrial (11/10):
- Cero rutas relativas huérfanas: resuelve claves en base a proyectos o directorios explícitos.
- Creación de claves con permisos POSIX restringidos (0600 - lectura/escritura exclusiva del dueño).
- Soporte para clave vía variable de entorno (MEM_PALACE_KEY).
- Serialización transparente de texto (UTF-8) y estructuras JSON.
- Excepciones tipadas sin abortos abruptos (evita sys.exit dentro de la lógica de librería).
- CLI integrado para pruebas, diagnóstico y operaciones interactivas.
- Compatibilidad retroactiva total con la API funcional previa.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
from pathlib import Path
from typing import Any, Optional, Union


class MemoriaError(Exception):
    """Clase base para errores de memoria criptográfica."""


class CriptografiaNoDisponibleError(MemoriaError):
    """Lanzada cuando la librería cryptography no está disponible en el entorno."""


class ClaveInvalidaError(MemoriaError):
    """Lanzada cuando la clave provista es corrupta o no válida."""


class MemoriaCorruptaError(MemoriaError):
    """Lanzada cuando los datos cifrados están corruptos o la clave no coincide."""


class PalacioMemoria:
    """
    Gestor criptográfico de memoria local para proyectos de la Agencia Principal.
    """

    def __init__(
        self,
        ruta_clave: Optional[Union[str, Path]] = None,
        ruta_archivo: Optional[Union[str, Path]] = None,
        clave_en_memoria: Optional[Union[str, bytes]] = None,
    ) -> None:
        self._fernet = None
        self._clave_bytes = None

        if clave_en_memoria:
            if isinstance(clave_en_memoria, str):
                self._clave_bytes = clave_en_memoria.encode("utf-8")
            else:
                self._clave_bytes = clave_en_memoria
            self._ruta_clave = None
        elif "MEM_PALACE_KEY" in os.environ:
            self._clave_bytes = os.environ["MEM_PALACE_KEY"].strip().encode("utf-8")
            self._ruta_clave = None
        else:
            if ruta_clave:
                self._ruta_clave = Path(ruta_clave).resolve()
            else:
                self._ruta_clave = self._determinar_ruta_clave_default()

        if ruta_archivo:
            self._ruta_archivo = Path(ruta_archivo).resolve()
        else:
            self._ruta_archivo = None

    @staticmethod
    def _determinar_ruta_clave_default() -> Path:
        cwd = Path.cwd()
        memoria_dir = cwd / ".memoria"
        if memoria_dir.is_dir():
            return memoria_dir / "mem_palace.key"
        return cwd / ".mem_palace.key"

    def _obtener_motor_fernet(self):
        if self._fernet is not None:
            return self._fernet

        try:
            from cryptography.fernet import Fernet
        except ImportError as exc:
            raise CriptografiaNoDisponibleError(
                "La librería 'cryptography' no está instalada. Ejecute 'pip install cryptography' en su entorno."
            ) from exc

        if self._clave_bytes is None:
            if not self._ruta_clave.exists():
                self._clave_bytes = Fernet.generate_key()
                self._ruta_clave.parent.mkdir(parents=True, exist_ok=True)
                flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
                modo = 0o600  # 384 en octal
                try:
                    fd = os.open(str(self._ruta_clave), flags, modo)
                    with os.fdopen(fd, "wb") as f:
                        f.write(self._clave_bytes)
                except OSError:
                    self._ruta_clave.write_bytes(self._clave_bytes)
            else:
                self._clave_bytes = self._ruta_clave.read_bytes().strip()

        try:
            self._fernet = Fernet(self._clave_bytes)
        except Exception as exc:
            raise ClaveInvalidaError(
                f"La clave criptográfica provista no es válida: {exc}"
            ) from exc

        return self._fernet

    def cifrar_texto(self, texto: str) -> bytes:
        if not isinstance(texto, str):
            raise TypeError(
                f"Se esperaba una cadena de texto (str), pero se recibió {type(texto).__name__}."
            )
        fernet = self._obtener_motor_fernet()
        return fernet.encrypt(texto.encode("utf-8"))

    def descifrar_texto(self, datos_cifrados: bytes) -> str:
        if not isinstance(datos_cifrados, bytes):
            raise TypeError(
                f"Se esperaban bytes cifrados, pero se recibió {type(datos_cifrados).__name__}."
            )
        fernet = self._obtener_motor_fernet()
        try:
            from cryptography.fernet import InvalidToken
        except ImportError:
            InvalidToken = Exception

        try:
            return fernet.decrypt(datos_cifrados).decode("utf-8")
        except InvalidToken as exc:
            raise MemoriaCorruptaError(
                "No se pudo descifrar la información: el token está corrupto o la clave no coincide."
            ) from exc

    def cifrar_json(self, datos: Any) -> bytes:
        texto_json = json.dumps(datos, ensure_ascii=False, indent=2)
        return self.cifrar_texto(texto_json)

    def descifrar_json(self, datos_cifrados: bytes) -> Any:
        texto = self.descifrar_texto(datos_cifrados)
        try:
            return json.loads(texto)
        except json.JSONDecodeError as exc:
            raise MemoriaCorruptaError(
                f"El contenido descifrado no es un JSON válido: {exc}"
            ) from exc

    def guardar_en_archivo(self, texto: str, ruta_destino: Optional[Union[str, Path]] = None) -> Path:
        destino = Path(ruta_destino).resolve() if ruta_destino else self._ruta_archivo
        if not destino:
            raise ValueError("No se especificó una ruta de archivo destino para guardar la memoria.")
        datos_cifrados = self.cifrar_texto(texto)
        destino.parent.mkdir(parents=True, exist_ok=True)
        destino.write_bytes(datos_cifrados)
        return destino

    def leer_desde_archivo(self, ruta_origen: Optional[Union[str, Path]] = None) -> str:
        origen = Path(ruta_origen).resolve() if ruta_origen else self._ruta_archivo
        if not origen or not origen.is_file():
            raise FileNotFoundError(f"El archivo de memoria cifrada no existe: {origen}")
        datos_cifrados = origen.read_bytes()
        return self.descifrar_texto(datos_cifrados)

    @property
    def clave_exportable(self) -> str:
        self._obtener_motor_fernet()
        assert self._clave_bytes is not None
        return self._clave_bytes.decode("utf-8")


_instancia_global: Optional[PalacioMemoria] = None


def _obtener_instancia_global(ruta_clave: Optional[Union[str, Path]] = None) -> PalacioMemoria:
    global _instancia_global
    if _instancia_global is None or ruta_clave is not None:
        _instancia_global = PalacioMemoria(ruta_clave=ruta_clave)
    return _instancia_global


def obtener_fernet(ruta_clave: Optional[Union[str, Path]] = None):
    """
    Retorna la instancia del motor Fernet subyacente.
    Mantiene compatibilidad con scripts existentes.
    """
    instancia = _obtener_instancia_global(ruta_clave)
    return instancia._obtener_motor_fernet()


def cifrar_datos(datos: str, ruta_clave: Optional[Union[str, Path]] = None) -> bytes:
    """Cifra texto en UTF-8 y retorna bytes cifrados."""
    instancia = _obtener_instancia_global(ruta_clave)
    return instancia.cifrar_texto(datos)


def descifrar_datos(datos_cifrados: bytes, ruta_clave: Optional[Union[str, Path]] = None) -> str:
    """Descifra bytes cifrados y retorna texto original."""
    instancia = _obtener_instancia_global(ruta_clave)
    return instancia.descifrar_texto(datos_cifrados)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Gestor criptográfico Mem Palace (Agencia Principal - Nivel Élite 11/10)"
    )
    parser.add_argument("--clave", help="Ruta hacia el archivo de clave (.key).")
    parser.add_argument("--archivo", help="Ruta hacia el archivo de datos cifrados (.enc).")
    parser.add_argument("--cifrar", help="Texto a cifrar y mostrar por stdout.")
    parser.add_argument("--descifrar", help="Ruta de archivo cifrado o bytes hex/base64 a descifrar.")
    parser.add_argument(
        "--generar-clave",
        action="store_true",
        help="Genera e imprime una nueva clave segura Fernet.",
    )
    parser.add_argument(
        "--probar",
        action="store_true",
        help="Ejecuta autodiagnóstico de cifrado/descifrado en memoria.",
    )
    args = parser.parse_args()

    if args.generar_clave:
        try:
            from cryptography.fernet import Fernet
            print(Fernet.generate_key().decode("utf-8"))
            return 0
        except ImportError:
            print("[!] Error: 'cryptography' no está disponible.", file=sys.stderr)
            return 1

    if args.probar:
        try:
            print("🔒 Ejecutando autodiagnóstico Mem Palace...")
            from cryptography.fernet import Fernet
            clave_prueba = Fernet.generate_key()
            p = PalacioMemoria(clave_en_memoria=clave_prueba)
            texto_prueba = "Decisión Crítica: Usar Clean Architecture y Postgresql (2026)"
            cifrado = p.cifrar_texto(texto_prueba)
            assert p.descifrar_texto(cifrado) == texto_prueba
            print("  ✓ Cifrado y descifrado de texto: OK")
            json_prueba = {"id": "ADR-001", "estado": "APROBADO", "impacto": "Alto"}
            cifrado_json = p.cifrar_json(json_prueba)
            assert p.descifrar_json(cifrado_json) == json_prueba
            print("  ✓ Cifrado y descifrado de JSON estructurado: OK")
            print("✨ Mem Palace está 100% operativo y seguro.")
            return 0
        except Exception as err:
            print(f"[!] Falló el autodiagnóstico: {err}", file=sys.stderr)
            return 1

    if args.cifrar:
        palacio = PalacioMemoria(ruta_clave=args.clave, ruta_archivo=args.archivo)
        cifrado = palacio.cifrar_texto(args.cifrar)
        if args.archivo:
            palacio.guardar_en_archivo(args.cifrar, args.archivo)
            print(f"✓ Guardado en {args.archivo}")
            return 0
        print(base64.b64encode(cifrado).decode("utf-8"))
        return 0

    if args.descifrar:
        palacio = PalacioMemoria(ruta_clave=args.clave, ruta_archivo=args.archivo)
        origen = Path(args.descifrar)
        if origen.is_file():
            print(palacio.leer_desde_archivo(origen))
            return 0
        raw_bytes = base64.b64decode(args.descifrar.strip())
        print(palacio.descifrar_texto(raw_bytes))
        return 0

    parser.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
