# cf-terraform-lab

A runnable, teachable lab for ten Terraform × Cloudflare × GitHub topics,
built against a real Cloudflare zone and real GitHub Actions.

**Safety model (read first):**
- Build only. Nothing pre-existing is ever modified or destroyed.
- Every resource the lab creates is named `lab-*` or lives under `lab.<zone>`.
- An OPA destroy-guard (`policy/destroy_guard.rego`) fails any plan that
  destroys a resource without the lab marker.
- No secret ever enters this repository: tokens live in `~/.cf-lab-env`
  (sourced, untracked); pre-commit + gitleaks block the rest.

| Where | What |
|---|---|
| `infra/modules/` | `zone-baseline` (T7/T9) · `waf-composed` (T10/T11) · `tunnel-site` (T14) |
| `infra/envs/lab` | the only applying root — own state (R2), own tfvars |
| `policy/` | OPA/rego evaluated on plan JSON and WAF fragments |
| `tests/` | tier-one offline unit tests (T24); `tests/contract/` applies real `tftest-` resources |
| `scripts/` | one demo script per topic |
| `demos/` | deliberately-broken counter-examples (T9 conflict, T32 sharp edges) |
| `brownfield/` | T29 adoption sandbox |
| `docs/` | LAB-GUIDE, per-topic runbooks, 2-hour session runsheet, teardown |

Start with [docs/LAB-GUIDE.md](docs/LAB-GUIDE.md).
