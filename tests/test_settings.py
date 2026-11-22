#!/usr/bin/env python3
"""Guard the portable settings layer: model prices, input/output and FreePi."""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = ROOT / "scripts"


class ModelSettingsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.script = (SCRIPTS / "setup-model-settings.sh").read_text(encoding="utf-8")

    def test_every_freepi_provider_is_configured(self) -> None:
        for pid in ("freepi", "freepi2", "freepi3", "freepi4", "freepi5", "freepi6", "freepi7"):
            self.assertIn(pid, self.script, pid)

    def test_input_output_and_efforts_are_pinned(self) -> None:
        self.assertIn("FREEPI_CONTEXT=1048576", self.script)
        self.assertIn("FREEPI_OUTPUT=32768", self.script)
        self.assertIn("FREEPI_EFFORTS=none,minimal,low,medium,high,xhigh,max", self.script)
        self.assertIn("--context", self.script)
        self.assertIn("--output", self.script)
        self.assertIn("--vision on", self.script)

    def test_prices_cover_input_and_output(self) -> None:
        self.assertIn("*/deepseek-v4.1-flash", self.script)
        self.assertIn("1,4,0.1,1.25", self.script)
        self.assertIn("*/jev-1.13-free", self.script)

    def test_queue_and_one_slot_per_account(self) -> None:
        self.assertIn("provider queue", self.script)
        self.assertIn(" 32 0", self.script)
        self.assertIn("account-concurrency", self.script)

    def test_no_secret_material(self) -> None:
        for needle in ("sk-", "oc_", "nvapi-", "eyJ"):
            self.assertNotIn(needle, self.script, needle)


class InstallerTests(unittest.TestCase):
    def test_freepi7_is_installable_and_loginable(self) -> None:
        plugins = (SCRIPTS / "plugins.sh").read_text(encoding="utf-8")
        login = (SCRIPTS / "login.sh").read_text(encoding="utf-8")
        doctor = (SCRIPTS / "doctor.sh").read_text(encoding="utf-8")
        self.assertIn("FreePiLogin7", plugins)
        self.assertIn("freepi7", login)
        self.assertIn("FreePi7:freepi7", doctor)

    def test_finish_does_not_reset_user_groups(self) -> None:
        finish = (SCRIPTS / "finish.sh").read_text(encoding="utf-8")
        self.assertNotRegex(finish, r"setup-groups\.sh\"\s+--force")

    def test_settings_seed_has_current_ui_values(self) -> None:
        settings = (SCRIPTS / "setup-settings.sh").read_text(encoding="utf-8")
        self.assertIn('"visionEffort": "max"', settings)
        self.assertIn('"disabledModels"', settings)
        self.assertIn('"serial": true', settings)


class SettingsFileTests(unittest.TestCase):
    def test_billion_context_has_no_secrets(self) -> None:
        raw = (ROOT / "config" / "billion-context.json").read_text(encoding="utf-8")
        for needle in re.findall(r"(?i)(sk-[A-Za-z0-9_-]{8,}|oc_[A-Za-z0-9_-]{8,})", raw):
            self.fail(f"secret-looking value in config: {needle[:8]}…")


if __name__ == "__main__":
    unittest.main(verbosity=2)
