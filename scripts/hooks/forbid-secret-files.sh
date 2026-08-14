#!/usr/bin/env bash
# pre-commit hook: block state/credential-shaped FILES from ever being staged.
set -euo pipefail
rc=0
for f in "$@"; do
  case "$f" in
    *.tfstate|*.tfstate.*|*.tfvars|*.tfvars.json|*.tfplan|.env|*.pem|*.key)
      echo "BLOCKED secret-risk file: $f"; rc=1 ;;
    *.terraform/*)
      echo "BLOCKED .terraform dir file: $f"; rc=1 ;;
  esac
done
exit $rc
