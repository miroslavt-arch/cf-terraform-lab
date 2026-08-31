#!/usr/bin/env bash
# Topic 27 — drift detection, CI-native version.
#
# The local demo (demo-27-make-drift.sh) drifts a record owned by envs/lab,
# whose state lives on the instructor's machine. A GitHub runner has no such
# state, and re-applying envs/lab from empty state would try to CREATE records
# that already exist. So the CI version owns its own resource end to end:
#
#   create -> drift it out of band -> detect (exit 2) -> attribute -> heal ->
#   destroy
#
# Same mechanism, same script for the report, no shared state required.
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN LAB_ZONE
env_dir="$REPO_ROOT/infra/envs/ci-demo"
cd "$env_dir"

say "Topic 27: drift is found by an exit code, then attributed to a human"

note "0/5 - creating a record for this demo to own..."
terraform init -input=false >/dev/null
terraform apply -auto-approve -input=false -var "zone_name=$LAB_ZONE" >/dev/null
fqdn="lab-ci-demo.lab.$LAB_ZONE"
zone_id=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')
rec=$(cf_api GET "/zones/$zone_id/dns_records?name=$fqdn")
rec_id=$(echo "$rec" | jq -r '.result[0].id')
green "created $fqdn (ttl=$(echo "$rec" | jq -r '.result[0].ttl'))"

note "1/5 - making drift: PATCHing the TTL out of band, exactly as a dashboard click would..."
cf_api PATCH "/zones/$zone_id/dns_records/$rec_id" CLOUDFLARE_API_TOKEN '{"ttl": 900}' \
  | jq -r '"  drifted: ttl -> " + (.result.ttl|tostring)'

note "2/5 - the detector: plan -detailed-exitcode (0 clean / 1 error / 2 drift)..."
set +e
terraform plan -refresh-only -detailed-exitcode -input=false -no-color -var "zone_name=$LAB_ZONE" -out=drift.tfplan >/dev/null
code=$?
set -e
case $code in
  0) red "no drift detected - the PATCH did not take"; exit 1 ;;
  2) green "exit code 2 - drift detected, exactly as the nightly workflow would see it" ;;
  *) red "plan errored (exit $code)"; exit 1 ;;
esac

note "3/5 - rendering the drift to JSON and attributing the author..."
terraform show -json drift.tfplan > drift.json
CF_ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-$CF_ACCOUNT_ID}" \
  python "$REPO_ROOT/scripts/drift_report.py" drift.json --hours 2

note "4/5 - healing: refresh-only apply, then a normal apply back to code truth..."
terraform apply -refresh-only -auto-approve -input=false -var "zone_name=$LAB_ZONE" >/dev/null
terraform apply -auto-approve -input=false -var "zone_name=$LAB_ZONE" >/dev/null
green "healed: ttl back to $(cf_api GET "/zones/$zone_id/dns_records?name=$fqdn" | jq -r '.result[0].ttl')"

note "5/5 - removing the demo record so this is repeatable..."
terraform destroy -auto-approve -input=false -var "zone_name=$LAB_ZONE" >/dev/null
rm -f drift.tfplan drift.json terraform.tfstate*
green "done. The structural fix is in the runbook: make humans read-only in the dashboard and let only the pipeline's token write."
