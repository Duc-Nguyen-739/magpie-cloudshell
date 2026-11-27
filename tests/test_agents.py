#!/usr/bin/env python3
"""Offline regression tests for agent profiles and the safe sync helper."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "config" / "agents"
CONTRACT = ROOT / "config" / "agent-contract.json"
CHECK = ROOT / "scripts" / "check-agents.py"
SYNC = ROOT / "scripts" / "sync-agents.py"
ROLES = ("leader", "review", "reviewplan", "coder", "tester", "tester2", "tester3")


def load_module(name: str, path: Path):
    import importlib.util

    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


validator = load_module("check_agents", CHECK)


def rules_for(role: str) -> list[dict]:
    meta, _ = validator.parse_profile((SOURCE / f"{role}.md").read_text(encoding="utf-8"), role)
    return validator.base_rules() + meta["permissions"]


class ValidatorTests(unittest.TestCase):
    def test_source_profiles_are_valid(self):
        self.assertEqual(validator.validate(SOURCE, CONTRACT), [])

    def test_missing_deny_is_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "agents"
            shutil.copytree(SOURCE, target)
            path = target / "leader.md"
            text = path.read_text(encoding="utf-8")
            text = text.replace(
                "  - action: read\n    resource: \"*\"\n    effect: deny",
                "  - action: read\n    resource: \"*\"\n    effect: allow",
            )
            path.write_text(text, encoding="utf-8")
            problems = validator.validate(target, CONTRACT)
            self.assertTrue(any("leader: missing rule read" in p for p in problems), problems)

    def test_invalid_effect_is_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "agents"
            shutil.copytree(SOURCE, target)
            path = target / "tester.md"
            text = path.read_text(encoding="utf-8").replace("effect: deny", "effect: maybe", 1)
            path.write_text(text, encoding="utf-8")
            problems = validator.validate(target, CONTRACT)
            self.assertTrue(any("bad effect" in p for p in problems), problems)


class PolicyTests(unittest.TestCase):
    def test_review_shell_allowlist(self):
        rules = rules_for("review")
        self.assertEqual(validator.decide(rules, "shell", "git status --short"), "allow")
        self.assertEqual(validator.decide(rules, "shell", "cd /tmp && git status --short"), "allow")
        self.assertEqual(validator.decide(rules, "shell", "echo '--- status ---'"), "allow")
        self.assertEqual(validator.decide(rules, "shell", "rm -rf /"), "deny")
        self.assertEqual(validator.decide(rules, "shell", "bash -c 'rm -rf /'"), "deny")

    def test_review_edit_scope(self):
        rules = rules_for("review")
        self.assertEqual(validator.decide(rules, "edit", "src/app.ts"), "deny")
        self.assertEqual(validator.decide(rules, "edit", ".opencode/plans/x/plan.md"), "allow")
        self.assertEqual(validator.decide(rules, "chrome-devtools_navigate_page", "*"), "deny")
        self.assertNotEqual(validator.decide(rules, "chrome_devtools_navigate_page", "*"), "deny")

    def test_reviewplan_browser_scope(self):
        rules = rules_for("reviewplan")
        self.assertEqual(validator.decide(rules, "chrome-devtools_navigate_page", "*"), "allow")
        self.assertNotEqual(validator.decide(rules, "chrome_devtools_navigate_page", "*"), "deny")

    def test_tester_edit_scope(self):
        rules = rules_for("tester")
        self.assertEqual(validator.decide(rules, "edit", "src/app.ts"), "deny")
        self.assertEqual(validator.decide(rules, "edit", "src/foo.tester1.test.ts"), "allow")
        self.assertEqual(validator.decide(rules, "edit", "foo.tester1.test.ts"), "allow")
        self.assertEqual(validator.decide(rules, "edit", "test_foo_tester1.py"), "allow")
        self.assertEqual(validator.decide(rules, "edit", "foo_tester1_test.go"), "allow")
        self.assertEqual(validator.decide(rules, "chrome-devtools_navigate_page", "*"), "deny")
        self.assertNotEqual(validator.decide(rules, "chrome_devtools_navigate_page", "*"), "deny")
        self.assertEqual(validator.decide(rules, "shell", "git commit -m x"), "deny")
        self.assertEqual(validator.decide(rules, "shell", "curl -X POST http://127.0.0.1:8080/api"), "allow")
        self.assertEqual(validator.decide(rules, "shell", "curl -X POST https://prod.example/api"), "deny")

    def test_leader_scope(self):
        rules = rules_for("leader")
        self.assertEqual(validator.decide(rules, "read", "src/app.ts"), "deny")
        self.assertEqual(validator.decide(rules, "execute", "*"), "deny")
        self.assertEqual(validator.decide(rules, "subagent", "review"), "allow")
        self.assertEqual(validator.decide(rules, "subagent", "build"), "deny")
        # Ngoại lệ vận hành duy nhất: script keepalive (tmux cũ + SSH mới), không mở đường cho loop tự do.
        self.assertEqual(validator.decide(rules, "shell", "cloudshell-keepalive --status"), "allow")
        self.assertEqual(validator.decide(rules, "shell", "cloudshell-keepalive-ssh --ensure"), "allow")
        self.assertEqual(validator.decide(rules, "shell", "cloudshell-keepalive-ssh --status"), "allow")
        self.assertEqual(validator.decide(rules, "shell", "sleep 1"), "deny")
        self.assertEqual(validator.decide(rules, "shell", "while :; do echo x; sleep 1; done"), "deny")
        # Quyền mới của Leader bản 2026-11-24.
        self.assertEqual(validator.decide(rules, "openchamber", "session.list"), "allow")
        self.assertEqual(validator.decide(rules, "magpie-sessions_search_sessions", "*"), "allow")
        self.assertEqual(validator.decide(rules, "shell", "sha256sum plan.md"), "allow")
        self.assertEqual(validator.decide(rules, "shell", "python3 scripts/plan-hash.py plan.md"), "allow")
        self.assertEqual(validator.decide(rules, "shell", "jq . config.json"), "allow")


class GateConfigTests(unittest.TestCase):
    def test_gate_config_enables_hash_and_prep(self):
        cfg = json.loads((ROOT / "config" / "leader-gate.json").read_text(encoding="utf-8"))
        self.assertTrue(cfg["artifactHash"])
        self.assertTrue(cfg["prepEnabled"])
        self.assertTrue(cfg["enforceOneSessionAll"])

    def test_gate_plugin_parses_artifact_fields(self):
        plugin = (ROOT / "config" / "plugins" / "leader-gate.js").read_text(encoding="utf-8")
        self.assertIn("import crypto from", plugin)
        self.assertIn("artifact_hash: kv.artifact_hash ||", plugin)
        self.assertIn("enforceOneSessionAll", plugin)


class SyncTests(unittest.TestCase):
    def run_sync(self, target: Path, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(SYNC), "--source", str(SOURCE), "--contract", str(CONTRACT), "--target", str(target), *args],
            text=True,
            capture_output=True,
            cwd=str(ROOT),
        )

    def test_install_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "agents"
            result = self.run_sync(target, "--install-missing")
            self.assertEqual(result.returncode, 0, result.stderr)
            for role in ROLES:
                self.assertTrue((target / f"{role}.md").is_file(), role)

    def test_preserve_local_model(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "agents"
            target.mkdir()
            for role in ROLES:
                shutil.copy2(SOURCE / f"{role}.md", target / f"{role}.md")
            path = target / "leader.md"
            text = path.read_text(encoding="utf-8").replace(
                "model: magpie/group/leader#max",
                "model: magpie/group/custom-local#high",
                1,
            )
            text += "\nSTALE LOCAL BODY\n"
            path.write_text(text, encoding="utf-8")
            result = self.run_sync(target, "--apply")
            self.assertEqual(result.returncode, 0, result.stderr)
            updated = path.read_text(encoding="utf-8")
            self.assertIn("model: magpie/group/custom-local#high", updated)
            self.assertNotIn("STALE LOCAL BODY", updated)
            self.assertTrue(any((target / "backups").glob("*/leader.md")))

    def test_setup_wrapper_sync_into_temp_home(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            env["HOME"] = tmp
            result = subprocess.run(
                ["bash", str(ROOT / "scripts" / "setup-opencode.sh"), "--sync", "--no-mcp"],
                text=True,
                capture_output=True,
                cwd=str(ROOT),
                env=env,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            target = Path(tmp) / ".config" / "opencode" / "agents"
            for role in ROLES:
                self.assertTrue((target / f"{role}.md").is_file(), role)

    def test_dry_run_reports_drift_without_writing(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "agents"
            target.mkdir()
            for role in ROLES:
                shutil.copy2(SOURCE / f"{role}.md", target / f"{role}.md")
            path = target / "leader.md"
            path.write_text(path.read_text(encoding="utf-8") + "\nSTALE\n", encoding="utf-8")
            before = path.read_bytes()
            result = self.run_sync(target, "--dry-run")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("WOULD WRITE", result.stdout)
            self.assertEqual(path.read_bytes(), before)
            self.assertFalse((target / "backups").exists())

    def test_expected_manifest_conflict_aborts(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "agents"
            target.mkdir()
            for role in ROLES:
                shutil.copy2(SOURCE / f"{role}.md", target / f"{role}.md")
            manifest = Path(tmp) / "manifest.json"
            manifest.write_text(json.dumps({role: "0" * 64 for role in ROLES}), encoding="utf-8")
            before = (target / "leader.md").read_bytes()
            result = self.run_sync(target, "--apply", "--expected-manifest", str(manifest))
            self.assertEqual(result.returncode, 3, result.stderr)
            self.assertEqual((target / "leader.md").read_bytes(), before)
            self.assertFalse((target / "backups").exists())

    def test_symlink_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "agents"
            target.mkdir()
            outside = Path(tmp) / "outside.md"
            outside.write_text("do not touch\n", encoding="utf-8")
            os.symlink(outside, target / "leader.md")
            result = self.run_sync(target, "--apply", "--install-missing")
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertEqual(outside.read_text(encoding="utf-8"), "do not touch\n")

    def test_unrelated_file_untouched(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "agents"
            target.mkdir()
            other = target / "other.md"
            other.write_text("custom\n", encoding="utf-8")
            result = self.run_sync(target, "--install-missing")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(other.read_text(encoding="utf-8"), "custom\n")

    def test_idempotent_after_apply(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "agents"
            target.mkdir()
            for role in ROLES:
                shutil.copy2(SOURCE / f"{role}.md", target / f"{role}.md")
            first = self.run_sync(target, "--apply")
            self.assertEqual(first.returncode, 0, first.stderr)
            backups = list((target / "backups").glob("*"))
            second = self.run_sync(target, "--apply")
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertIn("nothing to change", second.stdout)
            self.assertEqual(list((target / "backups").glob("*")), backups)


class ScenarioTests(unittest.TestCase):
    def test_scenarios_cover_task_modes(self):
        data = json.loads((ROOT / "tests" / "fixtures" / "agent-scenarios.json").read_text(encoding="utf-8"))
        modes = {item["task_mode"] for item in data["scenarios"]}
        self.assertTrue({"CONSULT", "PLAN", "CHANGE"} <= modes, modes)
        self.assertGreaterEqual(len(data["scenarios"]), 8)


if __name__ == "__main__":
    unittest.main(verbosity=2)
