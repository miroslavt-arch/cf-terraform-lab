#!/usr/bin/env bash
# TEARDOWN — removes what the lab created and NOTHING else.
#
#   scripts/teardown.sh            -> DRY RUN (default): list what would go
#   scripts/teardown.sh --execute  -> actually destroy, after a typed confirm
#
# Two independent safety nets:
#   1. terraform destroy only ever runs against the lab's own states
#   2. every planned deletion is checked for the lab marker (lab-/tftest-
#      prefix, .lab. hostname, or 'lab:' comment); ONE unmarked resource
#      aborts the whole run
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN LAB_ZONE

mode="dry-run"
[ "${1:-}" = "--execute" ] && mode="execute"

say "Lab teardown — mode: $mode"

check_plan_is_lab_only() { # $1 = dir, remaining = extra tf args
  local dir="$1"; shift
  terraform -chdir="$dir" plan -destroy -input=false -no-color -out=/tmp/teardown.tfplan "$@" >/dev/null
  terraform -chdir="$dir" show -json /tmp/teardown.tfplan > /tmp/teardown.json
  local victims unmarked
  victims=$(jq -r '.resource_changes[] | select(.change.actions | index("delete"))
    | (.address + "  ->  " + ((.change.before.name // .change.before.hostname // .change.before.comment // "?")|tostring))' /tmp/teardown.json)
  [ -z "$victims" ] && { note "  (nothing to destroy here)"; return 1; }
  echo "$victims" | sed 's/^/    /'
  unmarked=$(jq -r '[.resource_changes[] | select(.change.actions | index("delete"))
    | select(
        ((.change.before.name // "") | startswith("lab-") or startswith("tftest-") or contains(".lab.") or startswith("lab_")) or
        ((.change.before.comment // "") | contains("lab:")) or
        ((.change.before.hostname // "") | contains(".lab.")) or
        ((.change.before.description // "") | contains("lab")) or
        (.address | contains("lab"))
      | not)] | length' /tmp/teardown.json)
  if [ "$unmarked" != "0" ]; then
    red "ABORT: $unmarked resource(s) in this destroy plan carry NO lab marker. Nothing was destroyed."
    exit 1
  fi
  return 0
}

envs=("$ENV_LAB")

for env_dir in "${envs[@]}"; do
  note "environment: $env_dir"
  if check_plan_is_lab_only "$env_dir"; then
    if [ "$mode" = "execute" ]; then
      echo
      read -r -p "  type the zone name ($LAB_ZONE) to confirm destroying the resources listed above: " confirm
      if [ "$confirm" = "$LAB_ZONE" ]; then
        terraform -chdir="$env_dir" apply -input=false /tmp/teardown.tfplan
        green "  destroyed."
      else
        red "  confirmation mismatch — skipped."
      fi
    fi
  fi
done

note "brownfield adoption state (records were ADOPTED, not created — teardown deletes them because the seed script created them for the lab):"
if [ -d "$REPO_ROOT/brownfield/adopt/.terraform" ]; then
  zone_id=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')
  if check_plan_is_lab_only "$REPO_ROOT/brownfield/adopt" -var "zone_id=$zone_id" -var "zone_name=$LAB_ZONE"; then
    if [ "$mode" = "execute" ]; then
      terraform -chdir="$REPO_ROOT/brownfield/adopt" apply -input=false /tmp/teardown.tfplan
      green "  brownfield estate destroyed."
    fi
  fi
else
  note "  (brownfield never initialized — nothing to do)"
fi

note "residual demo roots (singleton-conflict, sharp-edges) hold no long-lived resources; their scripts reset themselves. Verify with:"
echo "    bash scripts/teardown-verify.sh   # lists any lab-* still visible via API"

if [ "$mode" = "dry-run" ]; then
  say "DRY RUN complete — nothing was destroyed. Re-run with --execute to proceed."
fi
