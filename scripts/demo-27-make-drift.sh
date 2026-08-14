#!/usr/bin/env bash
# Topic 27 — manufacture harmless drift on a lab- resource (the same PATCH a
# dashboard click would make), then run the detector + author attribution.
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN CLOUDFLARE_AUDIT_TOKEN CLOUDFLARE_ACCOUNT_ID LAB_ZONE
export CF_ACCOUNT_ID="$CLOUDFLARE_ACCOUNT_ID"
cd "$ENV_LAB"

say "Topic 27: drift is found nightly, rendered to JSON, and the audit log names the human"

note "1/3 — making drift: PATCHing lab-hello's TTL out of band (dashboard-equivalent API call)..."
zone_id=$(terraform output -raw zone_id)
rec_id=$(cf_api GET "/zones/$zone_id/dns_records?type=TXT&name=lab-hello.lab.$LAB_ZONE" | jq -r '.result[0].id')
cf_api PATCH "/zones/$zone_id/dns_records/$rec_id" CLOUDFLARE_API_TOKEN '{"ttl": 900}' \
  | jq -r '"  drifted: ttl -> " + (.result.ttl|tostring)'

note "2/3 — the detector: plan -detailed-exitcode (exit 2 = drift)..."
set +e
terraform plan -refresh-only -detailed-exitcode -input=false -no-color -out=drift.tfplan >/dev/null
code=$?
set -e
case $code in
  0) red "no drift detected?! (did step 1 fail?)"; exit 1 ;;
  2) green "exit code 2 — drift detected, exactly as the nightly workflow would see it" ;;
  *) red "plan errored"; exit 1 ;;
esac

note "3/3 — rendering to JSON and attributing the author from the audit log..."
terraform show -json drift.tfplan > drift.json
python "$REPO_ROOT/scripts/drift_report.py" drift.json --hours 2

note "reset: refresh-only apply + normal apply to restore code truth..."
terraform apply -refresh-only -auto-approve -input=false >/dev/null
terraform apply -auto-approve -input=false >/dev/null
rm -f drift.tfplan drift.json
green "drift healed. The runbook records the structural fix: humans get read-only dashboard roles; only the pipeline's token writes."
