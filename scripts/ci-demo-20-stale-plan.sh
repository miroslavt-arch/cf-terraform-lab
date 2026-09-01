#!/usr/bin/env bash
# Topic 20 - the plan-pinning invariant, CI-native version.
#
# The full human-gate demo IS the tf-pr / tf-apply pipeline. This script shows
# the invariant underneath it: a saved plan is a contract with the exact state
# it was computed from, and Terraform refuses to apply it once that state has
# moved.
#
# Uses infra/envs/ci-demo, which owns one record end to end, so it needs no
# pre-existing state.
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN LAB_ZONE
env_dir="$REPO_ROOT/infra/envs/ci-demo"
cd "$env_dir"

tf() { terraform "$@" -var "zone_name=$LAB_ZONE"; }
fqdn="lab-ci-demo.lab.$LAB_ZONE"
zone_id=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')

say "Topic 20: an approved plan is pinned to the exact state it was computed from. Move the world, and it is void."

note "0/4 - creating the record this demo owns..."
terraform init -input=false >/dev/null
tf apply -auto-approve -input=false >/dev/null
rec_id=$(cf_api GET "/zones/$zone_id/dns_records?name=$fqdn" | jq -r '.result[0].id')
green "created $fqdn"

note "1/4 - saving a plan. This is exactly what tf-pr stores as an artifact,"
note "      named after the commit SHA, and what a reviewer approves..."
tf plan -input=false -no-color -var "demo_note=approved by a reviewer" -out=pinned.tfplan >/dev/null
green "plan saved: pinned.tfplan"

note "2/4 - meanwhile, someone changes the record out of band (a dashboard click)..."
cf_api PATCH "/zones/$zone_id/dns_records/$rec_id" CLOUDFLARE_API_TOKEN '{"ttl": 600}' \
  | jq -r '"  out-of-band: ttl -> " + (.result.ttl|tostring)'
tf apply -refresh-only -auto-approve -input=false >/dev/null
green "state has moved on (a refresh recorded the out-of-band change)"

note "3/4 - now applying the SAVED plan - the one that was approved..."
# NOTE: no -var here. Terraform rejects -var when applying a saved plan file,
# because every value was already decided when the plan was computed.
#
# Capture first, then test. Under `set -o pipefail` a pipeline takes the
# failing status of ANY stage, and terraform exits non-zero here by design -
# so `terraform ... | grep -q` would report failure even when grep matched.
set +e
terraform apply -input=false -no-color pinned.tfplan > /tmp/stale.txt 2>&1
set -e
if grep -q "Saved plan is stale" /tmp/stale.txt; then
  echo
  grep -A4 "Saved plan is stale" /tmp/stale.txt | sed 's/^/    /'
  echo
  green "^ REFUSED. Not a warning - a refusal. The plan records the state serial it"
  green "  was computed against; if the state moved, applying it is undefined."
  green "  Process can be skipped at 3am. This cannot."
else
  red "apply unexpectedly succeeded - the invariant did not hold, investigate"
  tail -5 /tmp/stale.txt
fi

note "4/4 - cleaning up so this is repeatable..."
tf destroy -auto-approve -input=false >/dev/null
rm -f pinned.tfplan terraform.tfstate*
green "done. In the pipeline, that refusal is what stops a reviewer's approval being applied to a world it never saw."
