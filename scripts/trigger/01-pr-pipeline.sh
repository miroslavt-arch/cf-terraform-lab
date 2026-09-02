#!/usr/bin/env bash
# TRIGGER 1 — the push-driven pipeline. Topics 20 + 24 + 10, end to end.
#
# This is the only workflow in the lab that fires from a GIT EVENT rather than
# a button. It manufactures the event: a branch, a one-line change, a push, a
# pull request. tf-pr then runs on its own, and you watch it.
#
#   usage: bash scripts/trigger/01-pr-pipeline.sh [--auto-approve]
#
# --auto-approve is for REHEARSAL only. In the room, leave it off and click
# the gate yourself: the click is the point of the demo.
source "$(dirname "$0")/lib.sh"
need_gh; need_env CLOUDFLARE_API_TOKEN LAB_ZONE

AUTO="${1:-}"
BRANCH="demo/pipeline-$(date +%H%M%S)"
NOTE="approved by a human at $(date -u +%H:%M) UTC"

say "TRIGGER 1 — push a change, let the pipeline react"

note "1/6 — branching from main and making ONE reviewable change..."
git -C "$REPO_ROOT" checkout -q -b "$BRANCH"
# The demo_note default is the deliberate lever: changing it produces a small,
# legible plan diff on a lab- resource and nothing else.
sed -i -E "s|default     = \".*\"|default     = \"$NOTE\"|" "$REPO_ROOT/infra/envs/ci-demo/main.tf"
git -C "$REPO_ROOT" diff --stat | sed 's/^/    /'

note "2/6 — committing and pushing. THE PUSH IS THE TRIGGER..."
git -C "$REPO_ROOT" commit -aqm "demo: change the CI record's note

One-line change to a lab- resource, so the plan on the PR is small enough to
read out loud."
git -C "$REPO_ROOT" push -q -u origin "$BRANCH"

before=$(latest_run tf-pr.yml)
note "3/6 — opening the pull request..."
PR_URL=$(gh pr create --repo "$GH_REPO" --base main --head "$BRANCH" \
  --title "demo: change the CI record's note" \
  --body "Triggered live during the session. tf-pr will test, lint, plan with the **read-only** token, run the OPA destroy guard, and upload a plan artifact keyed by this commit's SHA.")
green "PR: $PR_URL"

say "Nobody clicked Run. The pull request itself started the pipeline."

note "4/6 — waiting for tf-pr (unit tests -> fmt -> conftest -> plan -> OPA -> artifact)..."
RUN_ID=$(wait_new_run tf-pr.yml "$before") || { red "tf-pr never started"; exit 1; }
echo "    run: $ACTIONS_URL/runs/$RUN_ID"
CC=$(wait_run "$RUN_ID")
[ "$CC" = "success" ] && green "tf-pr: $CC" || { red "tf-pr: $CC — open the run and read it"; exit 1; }

SHA=$(git -C "$REPO_ROOT" rev-parse HEAD)
say "The plan is now an ARTIFACT named tfplan-${SHA:0:7}... — not a promise to re-plan later."
echo "  Read the plan comment on the PR:   $PR_URL"
echo "  Artifact lives on run:             $ACTIONS_URL/runs/$RUN_ID"

note "5/6 — dispatching tf-apply, pinned to THAT artifact..."
before_apply=$(latest_run tf-apply.yml)
gh workflow run tf-apply.yml --repo "$GH_REPO" -f plan_run_id="$RUN_ID" -f sha="$SHA" >/dev/null
APPLY_ID=$(wait_new_run tf-apply.yml "$before_apply") || { red "tf-apply never started"; exit 1; }

say "STOP HERE AND LOOK AT THE SCREEN"
echo "  $ACTIONS_URL/runs/$APPLY_ID"
echo
echo "  The job is not slow. It is STOPPED. It has no write credential yet."
echo "  A 1-minute timer is running, and a named human has to tick a box."
echo
if [ "$AUTO" = "--auto-approve" ]; then
  note "(--auto-approve: approving for you. In the room, do this by hand.)"
  approve_gate "$APPLY_ID"
else
  echo "  DO IT NOW: open that URL -> Review deployments -> tick lab-apply -> Approve and deploy"
  echo
  read -r -p "  press Enter once you have approved... " _
fi

note "6/6 — applying the PINNED plan (not a fresh one)..."
CC=$(wait_run "$APPLY_ID")
if [ "$CC" = "success" ]; then
  green "tf-apply: success"
  live=$(cf_api GET "/zones/$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')/dns_records?name=lab-ci-demo.lab.$LAB_ZONE" \
         | jq -r '.result[0].content')
  green "live record content is now: $live"
else
  red "tf-apply: $CC"
fi

say "What my reviewer approved is the ONLY thing that executed. Byte for byte."
echo "  Cleanup when you are done:"
echo "    bash scripts/trigger/99-reset.sh"
