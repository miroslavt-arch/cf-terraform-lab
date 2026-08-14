#!/usr/bin/env bash
# Sharp edge 4 — the never-settling plan, and the honest fix.
# The bug: a trailing dot on a CNAME target. Correct DNS, wrong for this API.
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN LAB_ZONE
d="$REPO_ROOT/demos/sharp-edges/plan-noise"
zone_id=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')
tfvars=(-var "zone_id=$zone_id" -var "zone_name=$LAB_ZONE")

say "Sharp edge: you wrote a fully-qualified name with the trailing dot. The API stores it without. Your plan will now diff against a ghost, forever."

note "1/4 — applying the CNAME with the trailing dot ('example.com.')..."
terraform -chdir="$d/noisy" init -backend=false -input=false >/dev/null
terraform -chdir="$d/noisy" apply -auto-approve -input=false "${tfvars[@]}" >/dev/null
green "applied. API actually stored: $(cf_api GET "/zones/$zone_id/dns_records?name=lab-noise.lab.$LAB_ZONE" | jq -r '.result[0].content')"

note "2/4 — planning again, having changed NOTHING..."
terraform -chdir="$d/noisy" plan -input=false -no-color "${tfvars[@]}" | grep -E "~ content|^Plan:"
red "^ a diff, with zero code changes."

note "3/4 — 'fixing' it the way everyone tries first: apply again, twice..."
for i in 1 2; do
  terraform -chdir="$d/noisy" apply -auto-approve -input=false "${tfvars[@]}" >/dev/null
  echo "    after apply #$i: $(terraform -chdir="$d/noisy" plan -input=false -no-color "${tfvars[@]}" | grep -E '^(Plan:|No changes)')"
done
red "^ applying does not converge. This pipeline is never green again."

note "4/4 — the real fix: write the CANONICAL form (fixed/main.tf, no trailing dot)."
cp "$d/noisy"/terraform.tfstate "$d/fixed"/terraform.tfstate 2>/dev/null || true
terraform -chdir="$d/fixed" init -backend=false -input=false >/dev/null
terraform -chdir="$d/fixed" apply -auto-approve -input=false "${tfvars[@]}" >/dev/null
if terraform -chdir="$d/fixed" plan -input=false -no-color -detailed-exitcode "${tfvars[@]}" >/dev/null 2>&1; then
  green "plan is QUIET. Code truth now equals API truth, byte for byte."
else
  red "still noisy — investigate before teaching"
fi

say "Why not ignore_changes? It would silence this diff by no longer managing 'content' AT ALL — so a real repoint of this CNAME would also pass unnoticed. You'd trade a cosmetic itch for drift-blindness on the field that matters most."

note "reset: destroying the demo record..."
terraform -chdir="$d/fixed" destroy -auto-approve -input=false "${tfvars[@]}" >/dev/null 2>&1
rm -f "$d/noisy"/terraform.tfstate* "$d/fixed"/terraform.tfstate*
green "reset done."
