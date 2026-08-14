# Topic 27 — Drift detection: nightly baseline, author attribution, structural prevention

**Concept in three sentences.** Drift detection is a scheduled
`terraform plan -detailed-exitcode`: exit 0 is silence, exit 2 is drift, and
the drift plan rendered to JSON is a machine-readable list of exactly what
moved. The interesting question is never *what* drifted but *who* — so
`drift_report.py` joins the drifted resource ids against the Cloudflare
audit log and names the actor in the report. Detection is the fallback,
though: the structural fix is humans holding read-only dashboard roles while
only the pipeline's scoped token can write.

## Files
- `.github/workflows/drift.yml` — nightly cron + `workflow_dispatch` with a
  `-target` input; exit-2 handling; report into the job summary; loud red fail
- `scripts/drift_report.py` — plan-JSON × audit-log correlation
- `scripts/demo-27-make-drift.sh` — manufactures harmless drift + detects it

## Steps

```bash
bash scripts/demo-27-make-drift.sh      # end-to-end local version
# or the CI version: make a dashboard edit on a lab- record, then:
gh workflow run drift.yml               # and open the run's job summary
```

## Expected output *(unverified until first live run; report contract)*

```
exit code 2 — drift detected, exactly as the nightly workflow would see it

## Drift report
**1 resource(s) drifted from code truth:**
- `module.zone_baseline.cloudflare_dns_record.this["lab/lab-hello"]` — actions: update

### Who touched what (last 2h of audit log)
| when | actor | action | resource | id |
| 2026-08-14T..Z | miroslav.t@incloudites.com | rec_set | dns_record | abc... ⬅ **matches drifted resource** |

**Attribution: the marked actor made the out-of-band change.**
```

## Structural prevention (documented — deliberately NOT applied)
- **Role change that makes humans read-only:** dashboard → Manage account →
  Members → change the human member's role from *Administrator* to
  ***Administrator Read Only*** (Enterprise accounts also offer granular
  Domain-scoped read roles). Humans keep full visibility, lose the pencil.
  Not applied in this lab because the sandbox login *is* the instructor's
  only access — locking it read-only would end the class.
- **Token scoping that already limits writes:** the only write-capable
  credential (`lab-tf-apply-rw`) is zone-scoped + account-feature-scoped and
  lives exclusively inside the `lab-apply` GitHub environment behind the
  Topic 20 gate. The plan token and audit token physically cannot write.

## Failure mode prevented
Weeks-old dashboard hotfixes discovered mid-incident ("why is the TTL 900?");
drift conversations without an owner ("who changed this?" — the audit join
answers it); and the class of drift entirely, once humans are read-only.

## Reset
`demo-27-make-drift.sh` heals the drift itself (refresh-only apply + normal
apply). CI run leaves nothing behind.

## What to say
> "Exit code 2 is the whole detector. The report doesn't say 'something
> changed' — it says WHO, at WHAT time, from the audit log. And the real fix
> isn't detection at all: it's taking the pencil away from humans."
