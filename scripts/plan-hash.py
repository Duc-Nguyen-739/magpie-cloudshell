#!/usr/bin/env python3
"""Print the SELF-normalized sha256 of a plan file (read-only)."""
import hashlib
import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: plan-hash.py <plan.md>", file=sys.stderr)
        return 2
    data = Path(sys.argv[1]).read_bytes()
    data = re.sub(rb"(?m)^artifact_hash: .*$", b"artifact_hash: SELF", data, 1)
    print(hashlib.sha256(data).hexdigest())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
