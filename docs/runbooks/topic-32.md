# Topic 32 — Sharp edges: phase ownership, dual writers, list scale, plan noise

**Concept in three sentences.** Four production injuries, reproduced small
and reversible on `lab-` resources, each with its fix demonstrated. Two are
ownership fights the API referees differently (phase singleton → hard error;
DNS dual-writer → silent forever-flap), one is an architecture cost you can
only believe by measuring (500 resources vs 1), and one is a provider-
canonicalization itch with a tempting wrong fix. The meta-lesson is Topic 9
again and again: every shared thing needs exactly one owner.

## Files
`demos/sharp-edges/{phase-ownership,dual-writers,list-scale,plan-noise}/`
(each with its own README + roots) · `scripts/demo-32-{phase,dual,list,noise}.sh`

## 1. Phase ownership — `demo-32-phase.sh`
Two roots claim `http_request_late_transform`. A applies and owns it; B's
apply **fails** (`already exists`) — and the README walks the ping-pong that
starts when B's team "fixes" it by deleting A's ruleset.
*Expected:* A green → B red with the API's duplicate-phase error → reset.
**Fix:** one root per phase; teams contribute fragments (Topic 10).

## 2. Dual writers — `demo-32-dual.sh`
A creates `lab-dual` TXT; B *imports* it (innocent onboarding!) and applies
its own content. Live value flips B→A→B… both pipelines green forever.
*Expected:* `owned-by-A` → `owned-by-B` → A's plan shows "drift" → back to
`owned-by-A`.
**Fix:** one record, one owner root. **Detection:** Topic 27 — the audit log
shows the *other pipeline's token* as the drift actor.

## 3. List scale — `demo-32-list.sh` (real numbers, this account)
Same 500 IPs: `per-item/` = 500 `cloudflare_list_item` resources;
`bulk/` = one `cloudflare_list` with an `items` collection. The script
applies both, times `terraform plan` on each, then tears down (the bulk list
carries `prevent_destroy` — the script demonstrates the guard blocking
destroy, then uses the state-rm + API-delete path).

**⏱ Record after first run:** plan per-item = ___ s · plan bulk = ___ s ·
destroy per-item (500 deletes) = ___ s.

**Trade-off:** per-item buys per-item ownership at brutal refresh cost;
bulk is fast but single-owner. At 500 items the numbers decide.

## 4. Plan noise — `demo-32-noise.sh`
CNAME content written `LAB-App.LAB.<zone>`; the API stores lowercase; every
plan proposes the same no-op update, forever. Fix root writes the canonical
lowercase — plan goes quiet permanently.
*Expected:* `~ content` diff with zero code changes → after fix,
`-detailed-exitcode` returns 0.
**Why `ignore_changes` is the wrong fix:** it silences the phantom diff by
no longer managing content at all — a *real* repoint of the CNAME would
also pass unnoticed. You'd trade a cosmetic itch for drift-blindness on the
record's most important field. Match the canonical form instead.

## Failure modes prevented
Ruleset ping-pong wars between teams; unattributable eternal DNS drift;
plans that take minutes because someone modeled a list as 500 resources;
pipelines where "there's always some diff" trains humans to rubber-stamp.

## Reset
Every script resets itself (destroys only what it created — all `lab-`/
`lab_` prefixed; the destroy-guard convention applies). Residue check:
`bash scripts/teardown-verify.sh`.

## What to say
> "Four ways to get hurt, one pattern underneath: shared things with two
> owners. The API sometimes referees loudly, sometimes not at all — and the
> quiet ones are the expensive ones. Measure, assign owners, and never fix a
> noisy plan by telling Terraform to stop looking."
