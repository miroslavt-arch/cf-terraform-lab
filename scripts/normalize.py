#!/usr/bin/env python3
"""Topic 29 — normalize `terraform plan -generate-config-out` output.

Generated config is a faithful but ugly dump: null-valued optionals, computed
attributes echoed back, provider-canonicalized values. This rewrites a
generated .tf file into canonical form so the first plan after adoption is
QUIET — the gate before any refactor.

Usage: python scripts/normalize.py brownfield/adopt/generated_ruleset.tf
"""

import re
import sys


DROP_LINE_PATTERNS = [
    r"^\s*\w+\s*=\s*null\s*$",          # null optionals — noise
    r"^\s*id\s*=",                      # computed ids
    r"^\s*created_on\s*=",
    r"^\s*modified_on\s*=",
    r"^\s*last_updated\s*=",
    r"^\s*version\s*=\s*\"\d+\"",       # ruleset version is computed
]


def normalize(text: str) -> str:
    out = []
    for line in text.splitlines():
        if any(re.match(p, line) for p in DROP_LINE_PATTERNS):
            continue
        out.append(line.rstrip())
    # collapse >1 blank lines
    cleaned = re.sub(r"\n{3,}", "\n\n", "\n".join(out))
    if not cleaned.endswith("\n"):
        cleaned += "\n"
    return cleaned


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: normalize.py <generated.tf>")
    path = sys.argv[1]
    with open(path, encoding="utf-8") as fh:
        original = fh.read()
    cleaned = normalize(original)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(cleaned)
    removed = len(original.splitlines()) - len(cleaned.splitlines())
    print(f"normalized {path}: removed {removed} noise lines")


if __name__ == "__main__":
    main()
