#!/usr/bin/env bash
# Topic 10 — per-fragment linting: the app team's YAML is policed by policy
# the app team cannot edit (CODEOWNERS routes policy/ to security).
source "$(dirname "$0")/lib/common.sh"
cd "$REPO_ROOT"

say "Topic 10: every team's WAF fragment is linted ALONE — violations land on the offending PR, not on the merged ruleset"

note "1/2 — the real fragments (incident/security/app) against policy..."
conftest test --policy policy infra/modules/waf-composed/rules/
green "^ all fragments pass"

note "2/2 — the app team tries to ship a 'skip' action and an /admin match..."
if conftest test --policy policy policy/fixtures/bad-app-team.yaml; then
  red "the bad fixture passed?! the lint is broken"; exit 1
else
  green "^ BLOCKED, with messages that teach: skip is reserved, /admin belongs to security"
fi

note "ordering is by construction — the module concat()s incident -> security -> app:"
grep -n "ordered_rules = concat" infra/modules/waf-composed/main.tf
