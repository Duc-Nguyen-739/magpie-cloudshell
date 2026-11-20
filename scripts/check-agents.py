#!/usr/bin/env python3
"""Validate the seven agent profiles and their shared contract.

This is a repository-side lint, not a replacement for OpenCode's own
permission engine. It parses the small frontmatter subset this repo writes,
checks the required guardrails, and offers a last-match evaluator used by the
offline regression tests.

Usage:
    python3 scripts/check-agents.py
    python3 scripts/check-agents.py --source config/agents --contract config/agent-contract.json
    python3 scripts/check-agents.py --json
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROLES = ("leader", "review", "reviewplan", "coder", "tester", "tester2", "tester3")
EFFECTS = {"allow", "deny", "ask"}


class ProfileError(ValueError):
    pass


def _unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def _split_kv(line: str) -> tuple[str, str]:
    if ":" not in line:
        raise ProfileError(f"expected 'key: value', got: {line!r}")
    key, value = line.split(":", 1)
    return key.strip(), _unquote(value)


def parse_profile(text: str, name: str = "<profile>") -> tuple[dict, str]:
    """Parse the restricted YAML frontmatter used by config/agents/*.md."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        raise ProfileError(f"{name}: missing opening '---'")
    try:
        end = next(i for i in range(1, len(lines)) if lines[i].strip() == "---")
    except StopIteration as exc:
        raise ProfileError(f"{name}: missing closing '---'") from exc

    meta: dict = {}
    rules: list[dict] = []
    current: dict | None = None
    in_permissions = False

    def flush() -> None:
        nonlocal current
        if current is not None:
            rules.append(current)
            current = None

    for raw in lines[1:end]:
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if raw.startswith("  - "):
            flush()
            current = {}
            key, value = _split_kv(raw[4:])
            current[key] = value
        elif raw.startswith("    ") and current is not None:
            key, value = _split_kv(raw[4:])
            current[key] = value
        elif not raw.startswith(" "):
            flush()
            key, value = _split_kv(raw)
            if key == "permissions":
                in_permissions = True
                continue
            if in_permissions:
                raise ProfileError(f"{name}: unexpected top-level key after permissions: {key}")
            meta[key] = value
        else:
            raise ProfileError(f"{name}: unsupported indentation: {raw!r}")

    flush()
    if rules:
        meta["permissions"] = rules
    body = "\n".join(lines[end + 1 :]).strip()
    return meta, body


def match(pattern: str, value: str) -> bool:
    """OpenCode-style whole-value wildcard: * any chars, ? one char."""
    candidates = [pattern]
    if pattern.endswith(" *"):
        candidates.append(pattern[:-2])
    for candidate in candidates:
        regex = "^" + "".join(
            ".*" if ch == "*" else "." if ch == "?" else re.escape(ch)
            for ch in candidate
        ) + "$"
        if re.match(regex, value):
            return True
    return False


def decide(rules: list[dict], action: str, resource: str) -> str:
    """Return the last matching effect, or 'ask' when nothing matches."""
    effect = "ask"
    for rule in rules:
        if match(rule.get("action", ""), action) and match(rule.get("resource", ""), resource):
            effect = rule.get("effect", "ask")
    return effect


def base_rules() -> list[dict]:
    return [{"action": "*", "resource": "*", "effect": "allow"}]


def has_rule(rules: list[dict], action: str, resource: str, effect: str) -> bool:
    return any(
        r.get("action") == action
        and r.get("resource") == resource
        and r.get("effect") == effect
        for r in rules
    )


def require_rules(role: str, rules: list[dict], problems: list[str]) -> None:
    required = {
        "leader": [
            ("subagent", "*", "deny"),
            ("read", "*", "deny"),
            ("glob", "*", "deny"),
            ("grep", "*", "deny"),
            ("edit", "*", "deny"),
            ("shell", "*", "deny"),
            ("webfetch", "*", "deny"),
            ("websearch", "*", "deny"),
            ("skill", "*", "deny"),
            ("execute", "*", "deny"),
        ],
        "review": [
            ("subagent", "*", "deny"),
            ("question", "*", "deny"),
            ("edit", "*", "deny"),
            ("shell", "*", "deny"),
            ("skill", "magpie-skills", "deny"),
            ("skill", "openchamber-extensions", "deny"),
            ("chrome-devtools_*", "*", "deny"),
        ],
        "reviewplan": [
            ("subagent", "*", "deny"),
            ("question", "*", "deny"),
            ("edit", "*", "deny"),
            ("shell", "git push*", "deny"),
            ("shell", "git commit*", "deny"),
            ("shell", "rm *", "deny"),
            ("skill", "magpie-skills", "deny"),
            ("skill", "openchamber-extensions", "deny"),
        ],
        "coder": [
            ("subagent", "*", "deny"),
            ("question", "*", "deny"),
            ("edit", "**/.opencode/plans/**", "deny"),
            ("skill", "magpie-skills", "deny"),
            ("skill", "openchamber-extensions", "deny"),
            ("shell", "git push --force*", "deny"),
        ],
        "tester": [
            ("subagent", "*", "deny"),
            ("question", "*", "deny"),
            ("edit", "*", "deny"),
            ("skill", "magpie-skills", "deny"),
            ("skill", "openchamber-extensions", "deny"),
            ("chrome-devtools_*", "*", "deny"),
        ],
        "tester2": [
            ("subagent", "*", "deny"),
            ("question", "*", "deny"),
            ("edit", "*", "deny"),
            ("skill", "magpie-skills", "deny"),
            ("skill", "openchamber-extensions", "deny"),
            ("chrome-devtools_*", "*", "deny"),
        ],
        "tester3": [
            ("subagent", "*", "deny"),
            ("question", "*", "deny"),
            ("edit", "*", "deny"),
            ("skill", "magpie-skills", "deny"),
            ("skill", "openchamber-extensions", "deny"),
        ],
    }[role]
    for action, resource, effect in required:
        if not has_rule(rules, action, resource, effect):
            problems.append(f"{role}: missing rule {action} {resource!r} -> {effect}")


def require_text(role: str, body: str, problems: list[str]) -> None:
    common = {
        "leader": ["CONSULT", "PLAN", "CHANGE", "RELEASE", "PASS", "FAIL", "BLOCKED", "N/A", "baseline", "snapshot", "giữ plan"],
        "review": ["STANDARD", "STRICT", "PENDING", "APPLIED", "PARTIAL", "snapshot"],
        "reviewplan": ["PENDING", "APPLIED", "PARTIAL", "BLOCKED", "minor", "major", "snapshot"],
        "coder": ["snapshot", "không tự xoá plan", "baseline"],
        "tester": ["không mở browser", "snapshot", "ownership"],
        "tester2": ["không mở browser", "snapshot", "ownership"],
        "tester3": ["browser", "snapshot", "BLOCKED"],
    }[role]
    for needle in common:
        if needle not in body:
            problems.append(f"{role}: body must mention {needle!r}")


def require_no_text(role: str, body: str, problems: list[str]) -> None:
    forbidden = [
        "Luật Nhóm A",
        "cùng phiên nếu brief chưa duyệt",
        "session đóng",
        "Leader sẽ đọc lại code",
    ]
    if role == "leader":
        forbidden += ["rm -rf", "tự xoá plan"]
    for needle in forbidden:
        if needle in body:
            problems.append(f"{role}: forbidden text still present: {needle!r}")


def validate(source: Path, contract_path: Path) -> list[str]:
    problems: list[str] = []
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    roles = contract.get("roles", {})
    if set(roles) != set(ROLES):
        problems.append(f"contract roles must be exactly {sorted(ROLES)}")

    for role in ROLES:
        path = source / f"{role}.md"
        if not path.is_file():
            problems.append(f"{role}: missing {path}")
            continue
        text = path.read_text(encoding="utf-8")
        try:
            meta, body = parse_profile(text, role)
        except ProfileError as exc:
            problems.append(str(exc))
            continue

        expected = roles.get(role, {})
        description = meta.get("description", "")
        if not description:
            problems.append(f"{role}: missing description")
        elif len(description) > expected.get("description_max", 420):
            problems.append(f"{role}: description too long ({len(description)})")
        if meta.get("mode") != expected.get("mode"):
            problems.append(f"{role}: mode {meta.get('mode')!r} != {expected.get('mode')!r}")
        model = meta.get("model", "")
        if not model.startswith(expected.get("model_prefix", "")):
            problems.append(f"{role}: model {model!r} does not start with {expected.get('model_prefix')!r}")

        rules = meta.get("permissions", [])
        if not isinstance(rules, list) or not rules:
            problems.append(f"{role}: permissions must be a non-empty list")
            continue
        for index, rule in enumerate(rules, 1):
            if set(rule) != {"action", "resource", "effect"}:
                problems.append(f"{role}: permission {index} must have action/resource/effect")
                continue
            if rule["effect"] not in EFFECTS:
                problems.append(f"{role}: permission {index} bad effect {rule['effect']!r}")

        require_rules(role, rules, problems)
        require_text(role, body, problems)
        require_no_text(role, body, problems)

    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parent.parent / "config" / "agents")
    parser.add_argument("--contract", type=Path, default=Path(__file__).resolve().parent.parent / "config" / "agent-contract.json")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    problems = validate(args.source, args.contract)
    if args.json:
        print(json.dumps({"ok": not problems, "problems": problems}, ensure_ascii=False, indent=2))
    else:
        for problem in problems:
            print(f"ERROR {problem}", file=sys.stderr)
        print(f"{'ok' if not problems else 'failed'}: {len(ROLES)} profiles checked")
    return 0 if not problems else 1


if __name__ == "__main__":
    raise SystemExit(main())
