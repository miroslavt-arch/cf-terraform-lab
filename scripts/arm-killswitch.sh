#!/usr/bin/env bash
# Topic 11 — flip incident_mode in lab.auto.tfvars and show the PLAN diff.
# PLAN ONLY: applying is a separate, human decision (demo-11-arm.sh times the
# full loop; in production the break-glass PR + lab-apply gate do this).
# Usage: scripts/arm-killswitch.sh <none|elevated|lockdown>
source "$(dirname "$0")/lib/common.sh"

mode="${1:-}"
case "$mode" in
  none|elevated|lockdown) ;;
  *) red "usage: $0 <none|elevated|lockdown>"; exit 1 ;;
esac

tfvars="$ENV_LAB/lab.auto.tfvars"
[ -f "$tfvars" ] || { red "missing $tfvars — copy lab.auto.tfvars.example first"; exit 1; }

old=$(grep -E '^incident_mode' "$tfvars" | sed -E 's/.*"(.*)"/\1/')
sed -i.bak -E "s/^incident_mode *= *\"[a-z]+\"/incident_mode = \"$mode\"/" "$tfvars" && rm -f "$tfvars.bak"

say "Kill-switch: incident_mode  $old -> $mode  (tfvars flipped; nothing applied)"

note "planning — the diff should ONLY be 'enabled' flips on lab_ir_* rules..."
terraform -chdir="$ENV_LAB" plan -input=false -no-color | grep -E "^(  #|Plan:| +[~+-].*(enabled|ref))" || true

note "to arm for real: terraform -chdir=infra/envs/lab apply   (or the break-glass PR + tf-apply gate)"
