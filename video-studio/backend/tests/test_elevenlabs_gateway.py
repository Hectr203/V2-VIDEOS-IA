"""Pruebas unitarias para el Gateway de rotación ElevenLabs y selector dinámico de voces."""

import base64
import json
import unittest
from unittest.mock import patch

from services.elevenlabs_gateway import (
    ElevenLabsGateway,
    collect_elevenlabs_keys,
    mask_api_key,
)
from services.voice_hub import VoiceHub


class ElevenLabsGatewayTests(unittest.TestCase):
    def test_collect_keys_supports_indexed_comma_and_legacy_without_duplicates(self):
        env = {
            "ELEVENLABS_API_KEY_2": "sk_real_key_22222222",
            "ELEVENLABS_API_KEY_1": "sk_real_key_11111111",
            "ELEVENLABS_API_KEY_6": "sk_real_key_66666666",
            "ELEVENLABS_API_KEYS": "sk_real_key_11111111, sk_real_key_33333333",
            "ELEVENLABS_API_KEY": "sk_real_key_legacy99",
        }
        keys = collect_elevenlabs_keys(env)
        self.assertEqual(
            keys,
            [
                ("cuenta_1", "sk_real_key_11111111"),
                ("cuenta_2", "sk_real_key_22222222"),
                ("cuenta_6", "sk_real_key_66666666"),
                ("cuenta_3", "sk_real_key_33333333"),
                ("cuenta_4", "sk_real_key_legacy99"),
            ],
        )

    def test_rotates_automatically_when_first_account_below_threshold(self):
        calls = []

        def fake_req(url, api_key, method="GET", payload=None, timeout=30):
            calls.append((method, url, api_key))
            if url.endswith("/user/subscription"):
                if api_key == "sk_key_one_1111":
                    return 200, {"character_count": 9800, "character_limit": 10000, "tier": "free"}  # 200 left < 500
                return 200, {"character_count": 1000, "character_limit": 10000, "tier": "free"}  # 9000 left
            if "/text-to-speech/" in url:
                return 200, {
                    "audio_base64": base64.b64encode(b"FAKE_MP3_AUDIO").decode("ascii"),
                    "alignment": {"characters": ["H", "i"], "character_start_times_seconds": [0.0, 0.1], "character_end_times_seconds": [0.1, 0.2]},
                }
            raise AssertionError(f"URL inesperada: {url}")

        gw = ElevenLabsGateway(
            keys=[("cuenta_1", "sk_key_one_1111"), ("cuenta_2", "sk_key_two_2222")],
            min_credits_threshold=500,
            request_fn=fake_req,
        )
        res = gw.synthesize_with_failover("Hola mundo de prueba", "TX3LPaxmHKxFdv7VOQHJ")
        self.assertEqual(res["account_used"], "cuenta_2")
        self.assertEqual(res["audio_bytes"], b"FAKE_MP3_AUDIO")
        self.assertEqual(res["remaining_characters_estimate"], 9000 - len("Hola mundo de prueba"))

    def test_failover_during_tts_on_429_and_network_error(self):
        def fake_req(url, api_key, method="GET", payload=None, timeout=30):
            if url.endswith("/user/subscription"):
                return 200, {"character_count": 0, "character_limit": 10000, "tier": "free"}
            if "/text-to-speech/" in url:
                if api_key == "sk_key_one_1111":
                    return 429, {"detail": {"status": "quota_exceeded", "message": "Quota exceeded"}}
                if api_key == "sk_key_two_2222":
                    raise ConnectionError("timeout simulado")
                return 200, {"audio_base64": base64.b64encode(b"OK_FROM_3").decode("ascii"), "alignment": {}}
            raise AssertionError(url)

        gw = ElevenLabsGateway(
            keys=[
                ("cuenta_1", "sk_key_one_1111"),
                ("cuenta_2", "sk_key_two_2222"),
                ("cuenta_3", "sk_key_thr_3333"),
            ],
            min_credits_threshold=500,
            request_fn=fake_req,
        )
        res = gw.synthesize_with_failover("Texto de failover", "TX3LPaxmHKxFdv7VOQHJ")
        self.assertEqual(res["account_used"], "cuenta_3")
        self.assertEqual(res["audio_bytes"], b"OK_FROM_3")
        self.assertEqual(len(res["rotations"]), 2)

    def test_pool_status_and_errors_never_leak_raw_api_keys(self):
        secret_1 = "sk_super_secret_value_999999"
        secret_2 = "sk_another_secret_val_888888"

        def fake_req(url, api_key, method="GET", payload=None, timeout=30):
            return 401, {"detail": {"message": "Invalid API key"}}

        gw = ElevenLabsGateway(
            keys=[("cuenta_1", secret_1), ("cuenta_2", secret_2)],
            request_fn=fake_req,
        )
        status = gw.get_pool_status(force_refresh=True)
        serialized = json.dumps(status)
        self.assertNotIn(secret_1, serialized)
        self.assertNotIn(secret_2, serialized)
        self.assertEqual(status["available_accounts"], 0)
        self.assertIn(mask_api_key(secret_1), serialized)

        with self.assertRaises(RuntimeError) as ctx:
            gw.synthesize_with_failover("Hola", "TX3LPaxmHKxFdv7VOQHJ")
        self.assertNotIn(secret_1, str(ctx.exception))
        self.assertNotIn(secret_2, str(ctx.exception))

    def test_list_voices_returns_rich_metadata_and_filters_young_voices(self):
        def fake_req(url, api_key, method="GET", payload=None, timeout=30):
            if api_key == "sk_bad_key_0000":
                return 401, {"detail": "unauthorized"}
            return 200, {
                "voices": [
                    {
                        "voice_id": "TX3LPaxmHKxFdv7VOQHJ",
                        "name": "Liam",
                        "category": "premade",
                        "preview_url": "https://example.com/liam.mp3",
                        "labels": {"gender": "male", "age": "young", "accent": "american", "descriptive": "energetic", "use_case": "social_media"},
                    },
                    {
                        "voice_id": "JBFqnCBsd6RMkjVDRZzb",
                        "name": "George",
                        "category": "premade",
                        "preview_url": "https://example.com/george.mp3",
                        "labels": {"gender": "male", "age": "middle_aged", "accent": "british", "descriptive": "warm", "use_case": "narration"},
                    },
                ]
            }

        gw = ElevenLabsGateway(
            keys=[("cuenta_1", "sk_bad_key_0000"), ("cuenta_2", "sk_good_key_1234")],
            request_fn=fake_req,
        )
        all_v = gw.list_voices()
        self.assertEqual(all_v["account_used"], "cuenta_2")
        self.assertEqual(all_v["total"], 2)
        self.assertEqual(all_v["voices"][0]["name"], "Liam")  # jóvenes priorizados al inicio
        self.assertEqual(all_v["voices"][0]["age"], "Joven")

        young_only = gw.list_voices(age="joven")
        self.assertEqual(young_only["total"], 1)
        self.assertEqual(young_only["voices"][0]["id"], "TX3LPaxmHKxFdv7VOQHJ")

        with patch("services.voice_hub.get_elevenlabs_gateway", return_value=gw):
            catalog = VoiceHub.get_catalog()
            el = next(p for p in catalog if p["provider"] == "elevenlabs")
            self.assertEqual(len(el["voices"]), 2)
            self.assertEqual(el["voices"][0]["age"], "Joven")


if __name__ == "__main__":
    unittest.main()
