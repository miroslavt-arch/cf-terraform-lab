#!/usr/bin/env bash
# Topic 7 — typed interfaces fail FAST, at plan, with OUR error message.
# Runs a deliberately bad input, shows the custom error, then the good input.
# Offline: uses the mock-provider test harness, zero credentials.
source "$(dirname "$0")/lib/common.sh"
cd "$REPO_ROOT"

say "Topic 7: a module interface is a CONTRACT — bad input dies at plan, in the caller's terminal, with a message we wrote"

note "1/2 — feeding zone-baseline a record key WITHOUT the lab- prefix (violates the safety contract)..."
cat > /tmp/lab-demo07.tftest.hcl <<'EOF'
mock_provider "cloudflare" {}
run "bad_input" {
  command = plan
  module { source = "./infra/modules/zone-baseline" }
  variables {
    zones = {
      lab = {
        zone_id   = "0000000000000000000000000000dead"
        zone_name = "example.com"
        records   = { "prod-oops" = { type = "A", content = "192.0.2.1" } }
      }
    }
  }
}
EOF
mkdir -p tests/tmp-demo07 && cp /tmp/lab-demo07.tftest.hcl tests/tmp-demo07/demo.tftest.hcl
terraform init -backend=false -input=false -test-directory=tests/tmp-demo07 >/dev/null
if terraform test -test-directory=tests/tmp-demo07 2>&1 | grep -A4 "Invalid value for variable"; then
  green "^ the plan FAILED with the module's own error message — the bad record never got near the API"
else
  terraform test -test-directory=tests/tmp-demo07 || true
fi
rm -rf tests/tmp-demo07

note "2/2 — same shape, correct lab- prefix: the full unit suite passes..."
time terraform test
green "valid input planned clean. Validation is documentation that executes."
