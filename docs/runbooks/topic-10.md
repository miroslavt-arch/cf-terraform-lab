# Topic 10 — WAF ruleset composition: per-team fragments, ordering, per-fragment linting

**Concept in three sentences.** One zone gets one custom-rules ruleset, but
three teams need to contribute to it — so each team owns a YAML *fragment*
and the module composes them with `concat(incident, security, app)`: ordering
is guaranteed by construction, not by convention. Owner and review date are
interpolated into every rule description, so attribution survives into the
dashboard. Each fragment is linted alone by OPA policy the contributing team
cannot edit (CODEOWNERS routes `policy/` to security), so violations land on
the offending team's PR.

## Files
- `infra/modules/waf-composed/rules/{incident,security,app-team}.yaml`
- `infra/modules/waf-composed/main.tf` — `yamldecode` + the `concat` line +
  description stamping
- `policy/waf_fragments.rego` + `policy/fixtures/bad-app-team.yaml`
- `.github/CODEOWNERS` — one owner per fragment

## Steps

```bash
bash scripts/demo-10-fragment-lint.sh          # lint pass + lint fail
terraform -chdir=infra/envs/lab output waf_rule_order   # deployed order (after apply)
git log --oneline -- infra/modules/waf-composed/rules/  # per-fragment history
```

Dashboard proof (after apply): Security → Security rules → `lab-waf-composed`
— rules appear incident-first, each description prefixed `[owner:...|review:...]`.

## Expected output (REAL, captured 2026-08-14)

Good fragments:
```
12 tests, 12 passed, 0 warnings, 0 failures, 0 exceptions
```

Bad fixture (both violations, with teaching messages):
```
FAIL - policy/fixtures/bad-app-team.yaml - main - app-team fragment: rule
'lab_app_admin_grab' matches an /admin path. Admin-path handling belongs to
the security fragment (CODEOWNERS: security team).
FAIL - policy/fixtures/bad-app-team.yaml - main - app-team fragment: rule
'lab_app_sneaky_skip' uses action 'skip'. Skip bypasses the incident and
security rules that run above you — this action is reserved for the security
fragment.
```

`waf_rule_order` *(unverified until first apply)*:
```
["lab_ir_elevated_challenge", "lab_ir_lockdown_block",
 "lab_sec_block_admin_paths", "lab_sec_challenge_no_ua", "lab_app_log_beta"]
```

## Failure mode prevented
The app team's `skip` rule silently disabling the security rules above it;
rule reordering during "innocent" merges; orphan rules nobody owns or
reviews ("who added this block rule in 2023?").

## Reset
Nothing — the lint demo is read-only. The ruleset itself only changes when
fragments change.

## What to say
> "The concat line IS the org chart: incident above security above app, and
> no YAML edit can reorder someone else's rules. The lint runs per fragment,
> so the failure message lands on the right team's PR — policy as code
> reviewing code as YAML."
