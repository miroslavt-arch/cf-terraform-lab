#!/usr/bin/env bash
# TRIGGER 4 — tier-two contract tests, and the gate/automation tension. Topic 24.
#
# These tests create REAL tftest- resources on the lab zone and destroy them
# again. They need a write token. The only place the write token lives is the
# lab-apply environment, which requires human approval — so this scheduled
# workflow QUEUES rather than running unattended.
#
# That is not a bug to apologise for. It is the honest cost of putting the gate
# on the credential, and it is worth 30 seconds of the room's attention.
#
#   usage: bash scripts/trigger/04-contract-tests.sh
source "$(dirname "$0")/lib.sh"
need_gh

say "TRIGGER 4 — contract tests, and what a human gate costs you"

note "1/3 — is a scheduled run already sitting at the gate?"
gh run list --repo "$GH_REPO" --workflow contract-nightly.yml --limit 3 \
  --json databaseId,status,conclusion,createdAt \
  --jq '.[]|"    \(.databaseId)  status=\(.status)  conclusion=\(.conclusion // "-")  \(.createdAt)"'

say "A cron fired at 02:42 UTC and the job is STILL WAITING. Nobody was awake to approve it."

note "2/3 — dispatching one now and approving it, so you can see the tests actually run..."
before=$(latest_run contract-nightly.yml)
gh workflow run contract-nightly.yml --repo "$GH_REPO" >/dev/null
ID=$(wait_new_run contract-nightly.yml "$before") || { red "did not start"; exit 1; }
echo "    run: $ACTIONS_URL/runs/$ID"
approve_gate "$ID" || true
CC=$(wait_run "$ID")
if [ "$CC" = "success" ]; then
  green "contract tests: success — tftest- resources created against the real zone and destroyed"
else
  red "contract tests: $CC — open the run"
fi

say "The fix is not to remove the gate. It is to give CI its own narrow credential,"
say "scoped to tftest- resources only, and leave the human gate on production writes."

note "3/3 — tier one, for contrast: the same logic, offline, no credential at all."
terraform -chdir="$REPO_ROOT" test 2>&1 | tail -2 | sed 's/^/    /'
