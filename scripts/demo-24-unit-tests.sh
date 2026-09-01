#!/usr/bin/env bash
# Topic 24 — tier-one terraform test: provider mocked, zero credentials,
# zero network. Run this live with the stopwatch: `time` is the demo.
source "$(dirname "$0")/lib/common.sh"
cd "$REPO_ROOT"

# Ensure the provider mapping exists. Without init, mock_provider "cloudflare"
# resolves to hashicorp/cloudflare and every run fails with "Provider type
# mismatch" - which is what happens on a fresh CI runner.
[ -d .terraform ] || terraform init -backend=false -input=false >/dev/null

say "Topic 24: logic tests with mock_provider — no token, no API, no excuses not to run them on every PR"

# SECURITY: never `env | grep CLOUDFLARE` here. common.sh sources ~/.cf-lab-env,
# so that would print live token VALUES on a shared screen. Print names only,
# then run the suite with every credential explicitly stripped - which is a
# stronger proof anyway: not "there happen to be no tokens" but "these tests
# pass with the tokens forcibly removed".
note "credentials currently in this shell (names only, values never printed):"
env | grep -oE "^(CLOUDFLARE|AWS)_[A-Z_]+" | sed 's/^/  /' || echo "  (none)"

note "now running the suite with every one of them REMOVED from the environment:"
env -u CLOUDFLARE_API_TOKEN -u CLOUDFLARE_API_TOKEN_PLAN -u CLOUDFLARE_AUDIT_TOKEN     -u CLOUDFLARE_ACCOUNT_ID -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY     bash -c 'time terraform test'

green "5 runs: ordering, kill-switch arming, defaults, settings merge, and an expect_failures case."
note "tier two (tests/contract) applies REAL tftest- resources nightly — deliberately not part of this demo."
