#!/usr/bin/env bash
# Undo everything the trigger scripts create. Safe to run at any time, and
# safe to run twice. Touches only lab- resources and demo/ branches.
#
#   usage: bash scripts/trigger/99-reset.sh
source "$(dirname "$0")/lib.sh"
need_gh; need_env CLOUDFLARE_API_TOKEN LAB_ZONE

say "RESET — putting the lab back the way it started"

note "1/4 — closing demo PRs and deleting their branches..."
gh pr list --repo "$GH_REPO" --state open --json number,headRefName --jq '.[]|select(.headRefName|startswith("demo/"))|"\(.number) \(.headRefName)"' \
| while read -r num branch; do
    gh pr close "$num" --repo "$GH_REPO" --delete-branch >/dev/null 2>&1 \
      && echo "    closed PR #$num ($branch)" || echo "    could not close PR #$num"
  done

note "2/4 — returning the working tree to main..."
cur=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)
if [ "$cur" != "main" ]; then
  git -C "$REPO_ROOT" checkout -q -- infra/envs/ci-demo/main.tf 2>/dev/null || true
  git -C "$REPO_ROOT" checkout -q main
  git -C "$REPO_ROOT" branch -qD "$cur" 2>/dev/null || true
  echo "    was on $cur, now on main"
else
  echo "    already on main"
fi
git -C "$REPO_ROOT" fetch -qp origin 2>/dev/null || true

note "3/4 — disarming any incident rule and healing the ruleset..."
ZID=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')
RS=$(composed_ruleset_id)
if [ -n "$RS" ]; then
  for ref in lab_ir_elevated_challenge lab_ir_lockdown_block; do
    rid=$(cf_api GET "/zones/$ZID/rulesets/$RS" | jq -r --arg r "$ref" '.result.rules[]|select(.ref==$r)|.id')
    [ -n "$rid" ] && cf_api PATCH "/zones/$ZID/rulesets/$RS/rules/$rid" CLOUDFLARE_API_TOKEN '{"enabled":false}' >/dev/null
  done
fi
terraform -chdir="$ENV_LAB" apply -auto-approve -input=false >/dev/null 2>&1 || true

note "4/4 — verifying..."
echo "    envs/lab plan: $(terraform -chdir="$ENV_LAB" plan -input=false 2>&1 | grep -oE 'No changes|Plan: .*' | head -1)"
[ -n "$RS" ] && cf_api GET "/zones/$ZID/rulesets/$RS" \
  | jq -r '.result.rules[]|"    \(.ref) enabled=\(.enabled)"'
echo "    open demo PRs: $(gh pr list --repo "$GH_REPO" --state open --json headRefName --jq '[.[]|select(.headRefName|startswith("demo/"))]|length')"
green "reset complete."
