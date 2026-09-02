#!/usr/bin/env bash
# Shared plumbing for the TRIGGER scripts — the ones that manufacture, on
# demand, the conditions each workflow is built to react to.
#
# The demo-* scripts show a topic. These show a WORKFLOW: they create the
# real-world event (a pull request, drift in the dashboard, an armed
# kill-switch) and then let the pipeline notice it in front of the room.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

need_gh() {
  command -v gh >/dev/null 2>&1 || { red "gh CLI not found"; exit 1; }
  gh auth status >/dev/null 2>&1 || { red "gh not authenticated. Run: gh auth login"; exit 1; }
}

GH_REPO="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null \
  | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"

ACTIONS_URL="https://github.com/$GH_REPO/actions"

# Newest run id for a workflow file, or empty.
latest_run() { gh run list --repo "$GH_REPO" --workflow "$1" --limit 1 --json databaseId --jq '.[0].databaseId'; }

# Approve the lab-apply gate on a run that is waiting for it.
approve_gate() {
  local id="$1" env_id
  for _ in $(seq 1 30); do
    env_id=$(gh api "repos/$GH_REPO/actions/runs/$id/pending_deployments" --jq '.[0].environment.id' 2>/dev/null || true)
    if [ -n "${env_id:-}" ] && [ "$env_id" != "null" ]; then
      gh api "repos/$GH_REPO/actions/runs/$id/pending_deployments" -X POST \
        -f state=approved -f comment="approved from the trigger script" \
        -F "environment_ids[]=$env_id" >/dev/null && { green "gate approved"; return 0; }
    fi
    sleep 4
  done
  red "no pending deployment appeared on run $id"; return 1
}

# Block until a run finishes; return its conclusion on stdout.
wait_run() {
  local id="$1" st cc
  for _ in $(seq 1 150); do
    st=$(gh run view "$id" --repo "$GH_REPO" --json status --jq '.status' 2>/dev/null || echo "")
    [ "$st" = "completed" ] && break
    sleep 4
  done
  cc=$(gh run view "$id" --repo "$GH_REPO" --json conclusion --jq '.conclusion' 2>/dev/null || echo "unknown")
  echo "$cc"
}

# Wait for a NEW run of a workflow to appear (id different from $2).
wait_new_run() {
  local wf="$1" before="${2:-}" id
  for _ in $(seq 1 45); do
    id=$(latest_run "$wf")
    if [ -n "$id" ] && [ "$id" != "$before" ]; then echo "$id"; return 0; fi
    sleep 4
  done
  return 1
}

# The live composed ruleset — the object drift.yml and killswitch-reminder
# both read. Requires CLOUDFLARE_API_TOKEN and LAB_ZONE.
composed_ruleset_id() {
  local zid
  zid=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')
  cf_api GET "/zones/$zid/rulesets?per_page=50" \
    | jq -r '.result[]|select(.name=="lab-waf-composed")|.id'
}

# Flip one rule's `enabled` flag inside a ruleset.
#
# Cloudflare's per-rule PATCH REPLACES the rule rather than merging into it, so
# sending {"enabled":true} alone wipes action/expression and the API rejects
# it. Read the rule, change one field, send the whole thing back.
#   set_rule_enabled <zone_id> <ruleset_id> <ref> <true|false>
set_rule_enabled() {
  local zid="$1" rs="$2" ref="$3" want="$4" rule rid body
  rule=$(cf_api GET "/zones/$zid/rulesets/$rs" | jq -c --arg r "$ref" '.result.rules[]|select(.ref==$r)')
  [ -n "$rule" ] || { red "rule $ref not found in ruleset $rs"; return 1; }
  rid=$(echo "$rule" | jq -r '.id')
  body=$(echo "$rule" | jq -c --argjson e "$want"     '{action, expression, description, ref, enabled:$e} + (if .action_parameters then {action_parameters} else {} end)')
  cf_api PATCH "/zones/$zid/rulesets/$rs/rules/$rid" CLOUDFLARE_API_TOKEN "$body"     | jq -e '.success' >/dev/null
}
