# Topic 20 — GitHub environments as the human gate: reviewers, wait timers, scoped secrets

**Concept in three sentences.** The PR pipeline plans with a token that
*cannot write*, and stores the plan as an artifact keyed by commit SHA; the
apply pipeline runs in a protected environment holding the write token —
required reviewer plus a visible wait timer — and replays **exactly that
artifact**, never a fresh plan. So the thing a human approves is the thing
that executes, byte for byte. And if the world changed in between, Terraform
refuses the stale plan — the invariant is enforced by the tool, not by
process discipline.

## Files
- `.github/workflows/tf-pr.yml` — unit tests → lint → plan (RO token) →
  OPA destroy-guard → artifact `tfplan-<sha>` → PR comment
- `.github/workflows/tf-apply.yml` — `workflow_dispatch(plan_run_id, sha)`,
  environment `lab-apply`, downloads the pinned artifact, applies it
- `scripts/demo-20-stale-plan.sh` — the local, deterministic reproduction

## One-time setup (Settings → Environments — ~5 min)
1. **`lab-plan`** — secrets `CLOUDFLARE_API_TOKEN_PLAN`,
   `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `CLOUDFLARE_AUDIT_TOKEN`.
   No protection rules (planning is safe by token construction).
2. **`lab-apply`** — secrets `CLOUDFLARE_API_TOKEN`, `AWS_ACCESS_KEY_ID`,
   `AWS_SECRET_ACCESS_KEY`. Protection: **Required reviewers →
   miroslavt-arch**; **Wait timer → 1 minute** (long enough to SEE in a demo).
3. Repo variables: `CF_ACCOUNT_ID`, `LAB_ZONE`, `LAB_ZONE_ID`.

## Steps (live pipeline)
```bash
git checkout -b demo/ttl-bump
sed -i 's/ttl     = 300/ttl     = 600/' infra/envs/lab/main.tf
git commit -am "demo: bump lab-hello TTL" && git push -u origin demo/ttl-bump
gh pr create --fill
# -> tf-pr runs: plan comment appears on the PR; note the artifact name tfplan-<sha>
gh workflow run tf-apply.yml -f plan_run_id=<run-id> -f sha=<sha>
# -> the run PAUSES: wait timer counts down, then review-gate email; approve it
```

## Steps (the money demo — stale plan refusal)
```bash
bash scripts/demo-20-stale-plan.sh
```

## Expected output *(unverified until first live run)*

The refusal (Terraform's own message, verbatim shape):
```
Error: Saved plan is stale

The given plan file can no longer be applied because the state was changed
by another operation after the plan was created.
```

Plus, in the Actions UI: the `lab-apply` job sitting in
"Waiting for review" with the 60-second timer visibly counting.

## Failure mode prevented
Apply-what-you-planned drift: reviewer approves plan A, pipeline applies
plan B computed later against a moved world. Also: write credentials
reachable from unreviewed code (they exist only inside the gated
environment), and silent immediate applies (the wait timer buys an
"oh wait, stop" window).

## Reset
`demo-20-stale-plan.sh` restores TTL and deletes its plan file itself.
Close/revert the demo PR: `gh pr close demo/ttl-bump --delete-branch`.

## What to say
> "The artifact name is the commit SHA. What my reviewer approved is the
> ONLY thing this pipeline can execute — and when I moved the world after
> planning, Terraform itself said no. Process can be skipped; this can't."
