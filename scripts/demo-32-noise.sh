#!/usr/bin/env bash
# Sharp edge 4 — the never-settling plan, and the honest fix.
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN LAB_ZONE
d="$REPO_ROOT/demos/sharp-edges/plan-noise"
zone_id=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')
tfvars=(-var "zone_id=$zone_id" -var "zone_name=$LAB_ZONE")

say "Sharp edge: the API canonicalizes what you wrote — your plan diffs against a ghost, forever"

note "1/3 — applying the MixedCase CNAME..."
terraform -chdir="$d/noisy" init -backend=false -input=false >/dev/null
terraform -chdir="$d/noisy" apply -auto-approve -input=false "${tfvars[@]}" >/dev/null
green "applied. API stored: $(cf_api GET "/zones/$zone_id/dns_records?name=lab-noise.lab.$LAB_ZONE" | jq -r '.result[0].content')"

note "2/3 — planning again, changing NOTHING..."
if terraform -chdir="$d/noisy" plan -input=false -no-color "${tfvars[@]}" | grep -E "~ content|Plan:" ; then
  red "^ a diff, with zero code changes. Apply it and it comes back tomorrow. And the day after."
else
  note "(no diff shown — provider may have started normalizing case; check and update this demo)"
fi

note "3/3 — the fix: write the CANONICAL form (fixed/main.tf, lowercase). Migrating state to the fixed root..."
cp "$d/noisy"/terraform.tfstate "$d/fixed"/terraform.tfstate 2>/dev/null || true
terraform -chdir="$d/fixed" init -backend=false -input=false >/dev/null
if terraform -chdir="$d/fixed" plan -input=false -no-color -detailed-exitcode "${tfvars[@]}" >/dev/null 2>&1; then
  green "plan is QUIET. Code truth now equals API truth, character for character."
else
  terraform -chdir="$d/fixed" apply -auto-approve -input=false "${tfvars[@]}" >/dev/null
  terraform -chdir="$d/fixed" plan -input=false -no-color -detailed-exitcode "${tfvars[@]}" >/dev/null 2>&1 \
    && green "one settling apply, then QUIET forever." \
    || red "still noisy — investigate before teaching"
fi

say "Why not ignore_changes? Because then a REAL repoint of this CNAME would also be ignored — you'd trade a cosmetic diff for drift-blindness on the field that matters."

note "reset: destroying the demo record..."
terraform -chdir="$d/fixed" destroy -auto-approve -input=false "${tfvars[@]}" >/dev/null 2>&1 \
  || terraform -chdir="$d/noisy" destroy -auto-approve -input=false "${tfvars[@]}" >/dev/null
rm -f "$d/noisy"/terraform.tfstate* "$d/fixed"/terraform.tfstate*
green "reset done."
