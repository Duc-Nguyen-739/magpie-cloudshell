#!/usr/bin/env python3
"""Guard the portable billion-context profile and the compress group definition."""
from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "config" / "billion-context.json"


class BillionContextConfigTests(unittest.TestCase):
    def setUp(self) -> None:
        self.data = json.loads(CONFIG.read_text(encoding="utf-8"))
        self.models = self.data["providers"]["http://127.0.0.1:3425/v1"]["models"]

    def test_no_secret_values(self) -> None:
        raw = CONFIG.read_text(encoding="utf-8").lower()
        for needle in ("apikey", "api_key", "sk-", "password", "bearer "):
            self.assertNotIn(needle, raw, f"config must not contain {needle!r}")

    def test_external_summary_budget_and_target(self) -> None:
        ext = self.data["compress"]["externalSummary"]
        self.assertTrue(ext["enabled"])
        self.assertEqual(ext["targets"][0], "magpie/group/compress")
        self.assertEqual(ext["concurrency"], 8)
        self.assertEqual(ext["budget"]["targetTimeoutMs"], 900000)
        self.assertEqual(ext["budget"]["totalTimeoutMs"], 1200000)
        self.assertEqual(ext["budget"]["maxSummaryBytes"], 131072)

    def test_leader_keeps_long_memory(self) -> None:
        leader = self.models["group/leader"]["compress"]
        self.assertEqual(leader["preserveRecentTokens"], 300000)
        self.assertEqual(leader["preserveRecentMessages"], 40)
        self.assertEqual(leader["maxSummaryLength"], 60000)
        self.assertEqual(leader["maxContextLimit"], "75%")

    def test_review_protects_recent_reads(self) -> None:
        for name in ("group/review", "group/reviewplan"):
            compress = self.models[name]["compress"]
            self.assertEqual(compress["neverPreserveRecentTools"], [])
            self.assertEqual(compress["preserveRecentTools"], ["bash"])
            self.assertEqual(compress["maxContextLimit"], "35%")
            self.assertEqual(compress["preserveRecentTokens"], 60000)

    def test_compress_provider_output_is_large_enough(self) -> None:
        provider = self.data["providers"]["magpie"]["models"]
        self.assertEqual(provider["group/compress"]["outputTokens"], 32768)
        self.assertEqual(provider["workbuddy-ai/hy4flash-free"]["outputTokens"], 32768)

    def test_resolved_models_are_present(self) -> None:
        for name in (
            "workbuddy-ai/deepseek-v4.1-flash-sg",
            "xingchi/gpt-6.1-sol",
            "freepi4/deepseek-v4.1-flash",
            "freepi/deepseek-v4.1-flash",
            "freepi6/deepseek-v4.1-flash",
            "freepi2/deepseek-v4.1-flash",
            "freepi3/deepseek-v4.1-flash",
            "freepi5/deepseek-v4.1-flash",
            "autoclaw/zai_glm-5.3-flash",
        ):
            self.assertIn(name, self.models, name)


if __name__ == "__main__":
    unittest.main(verbosity=2)
