#!/usr/bin/env bash
# pre-commit hook: grep staged files for credential-shaped CONTENT.
set -euo pipefail
rc=0
pattern='(CLOUDFLARE|CF)_API_(TOKEN|KEY)[[:space:]]*=[[:space:]]*"?[A-Za-z0-9_-]{30,}|AWS_SECRET_ACCESS_KEY[[:space:]]*=[[:space:]]*"?[A-Za-z0-9/+=]{30,}|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}'
for f in "$@"; do
  [ -f "$f" ] || continue
  if grep -nE "$pattern" "$f"; then
    echo "BLOCKED credential-looking content in: $f"; rc=1
  fi
done
exit $rc
