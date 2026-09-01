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

note "proof there are no credentials in this shell:"
env | grep -E "^CLOUDFLARE" || echo "  (no CLOUDFLARE_* variables set)"

note "running the whole tier-one suite..."
time terraform test

green "5 runs: ordering, kill-switch arming, defaults, settings merge, and an expect_failures case."
note "tier two (tests/contract) applies REAL tftest- resources nightly — deliberately not part of this demo."
