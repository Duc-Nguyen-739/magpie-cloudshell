#!/usr/bin/env python3
"""Synchronise the seven agent profiles without touching unrelated config.

Modes:
    --check              report drift, exit 1 when a target differs (default)
    --dry-run            report what would change, exit 0
    --apply              back up and replace existing targets
    --install-missing    copy a target only when it does not exist

`--apply --install-missing` does both. This script only touches
<target>/<role>.md. It never calls magpie, MCP, OpenCode, setup-groups,
setup-mcp, or restarts a service.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

ROLES = ("leader", "review", "reviewplan", "coder", "tester", "tester2", "tester3")


def load_validator():
    path = Path(__file__).resolve().parent / "check-agents.py"
    spec = importlib.util.spec_from_file_location("check_agents", path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def model_line(text: str) -> str | None:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if line.startswith("model:"):
            return line
    return None


def with_model(source_text: str, line: str | None) -> str:
    if not line:
        return source_text
    lines = source_text.splitlines()
    for index, current in enumerate(lines):
        if current.startswith("model:"):
            lines[index] = line
            return "\n".join(lines) + ("\n" if source_text.endswith("\n") else "")
    raise ValueError("source profile has no model line")


def load_manifest(path: Path | None) -> dict[str, str]:
    if path is None:
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in data.items()):
        raise ValueError("expected manifest must be a JSON object of name -> sha256")
    return data


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parent.parent / "config" / "agents")
    parser.add_argument("--target", type=Path, default=Path.home() / ".config" / "opencode" / "agents")
    parser.add_argument("--contract", type=Path, default=Path(__file__).resolve().parent.parent / "config" / "agent-contract.json")
    parser.add_argument("--expected-manifest", type=Path)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--check", action="store_true", help="report drift (default)")
    group.add_argument("--dry-run", action="store_true", help="report planned changes")
    group.add_argument("--apply", action="store_true", help="write changed profiles")
    parser.add_argument("--install-missing", action="store_true", help="copy profiles that do not exist")
    args = parser.parse_args()

    if args.apply:
        mode = "apply"
    elif args.dry_run:
        mode = "dry-run"
    elif args.install_missing:
        mode = "install-missing"
    else:
        mode = "check"

    validator = load_validator()
    problems = validator.validate(args.source, args.contract)
    if problems:
        for problem in problems:
            print(f"ERROR {problem}", file=sys.stderr)
        print("source validation failed; nothing written", file=sys.stderr)
        return 2

    try:
        manifest = load_manifest(args.expected_manifest)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR expected manifest: {exc}", file=sys.stderr)
        return 2

    sources = {role: (args.source / f"{role}.md").read_bytes() for role in ROLES}
    targets = {role: args.target / f"{role}.md" for role in ROLES}

    installs: list[tuple[str, Path, bytes]] = []
    updates: list[tuple[str, Path, bytes]] = []
    missing: list[Path] = []
    drift: list[Path] = []

    # Preflight every target before writing anything.
    for role, target in targets.items():
        if target.is_symlink():
            print(f"ERROR {target} is a symlink; refusing to write", file=sys.stderr)
            return 2
        if not target.exists():
            missing.append(target)
            if mode in {"install-missing", "apply"} and (mode == "install-missing" or args.install_missing):
                installs.append((role, target, sources[role]))
            continue

        current = target.read_bytes()
        if manifest:
            expected = manifest.get(role)
            if expected is None:
                print(f"ERROR {target} missing from expected manifest; nothing written", file=sys.stderr)
                return 3
            if expected != sha256(current):
                print(f"ERROR {target} does not match the expected manifest; nothing written", file=sys.stderr)
                return 3

        desired = with_model(
            sources[role].decode("utf-8"),
            model_line(current.decode("utf-8")),
        ).encode("utf-8")
        if current != desired:
            drift.append(target)
            if mode in {"apply", "dry-run"}:
                updates.append((role, target, desired))

    if mode == "check":
        for target in drift:
            print(f"DRIFT {target}")
        for target in missing:
            print(f"MISSING {target}")
        if drift or missing:
            print("profiles differ from source; run --apply or --install-missing", file=sys.stderr)
            return 1
        print("ok: 7 profiles match source")
        return 0

    if mode == "dry-run":
        for _, target, _ in updates:
            print(f"WOULD WRITE {target}")
        for _, target, _ in installs:
            print(f"WOULD INSTALL {target}")
        if not updates and not installs:
            print("ok: nothing to change")
        return 0

    if mode == "install-missing":
        if not installs:
            print("ok: nothing to install")
            return 0
        args.target.mkdir(parents=True, exist_ok=True)
        for role, target, desired in installs:
            tmp = target.with_name(f".{target.name}.tmp.{os.getpid()}")
            tmp.write_bytes(desired)
            os.replace(tmp, target)
            print(f"INSTALLED {target}")
        print(f"changed: 0 updated, {len(installs)} installed")
        return 0

    # mode == apply
    if not updates and not installs:
        print("ok: nothing to change")
        return 0

    args.target.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup_dir = args.target / "backups" / stamp
    if updates:
        backup_dir.mkdir(parents=True, exist_ok=True)

    for role, target, desired in updates:
        shutil.copy2(target, backup_dir / f"{role}.md")
        tmp = target.with_name(f".{target.name}.tmp.{os.getpid()}")
        tmp.write_bytes(desired)
        os.replace(tmp, target)
        print(f"WROTE {target}")
    for role, target, desired in installs:
        tmp = target.with_name(f".{target.name}.tmp.{os.getpid()}")
        tmp.write_bytes(desired)
        os.replace(tmp, target)
        print(f"INSTALLED {target}")

    if updates:
        print(f"backup: {backup_dir}")
    print(f"changed: {len(updates)} updated, {len(installs)} installed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
