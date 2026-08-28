# LAB-GUIDE — cf-terraform-lab

A real, runnable lab for teaching ten Terraform × Cloudflare × GitHub topics
in a 2-hour session. Everything applies against the Cloudflare sandbox
account `f40b69d8637a12568c6a62d218822384`, zone **`zesty-beta.sxplab.com`**.

> **Note (2026-08-21):** the original sandbox (`gracious-binary.sxplab.com`,
> account `bc682468...`) was destroyed. The lab was repointed to the zone
> above with no code changes — only `~/.cf-lab-env` and
> `infra/envs/lab/lab.auto.tfvars`. Captured outputs under `docs/captures/`
> still name the old zone; they are kept as-is because they are records of
> runs that actually happened.

## What this lab creates, and what it costs

Everything is `lab-`-prefixed or lives under `lab.zesty-beta.sxplab.com`:

| Resource | Names | Topic |
|---|---|---|
| DNS records | `lab-hello`, `lab-app`, `lab-legacy-*`, demo records | 7, 14, 29, 32 |
| Zone settings | baseline of 5 (singleton-owned by `zone-baseline`) | 9 |
| WAF ruleset | `lab-waf-composed` (custom-rules phase) | 10, 11 |
| Tunnels | `lab-tunnel` (+ `lab-tunnel-g2` during rotation) | 14 |
| Ruleset | `lab-legacy-ratelimit` (rate-limit phase) | 29 |
| Account lists | `lab_scale_per_item`, `lab_scale_bulk` (demo-lifetime only) | 32 |
| R2 bucket | `lab-tfstate` (state backend) | — |

**Cost: $0.** The sandbox zone is Enterprise (no feature gates), R2 free tier
covers state ~1000×, GitHub Actions free tier covers a public repo.

## The safety model

1. **Build only.** Nothing that existed before the lab is modified or
   destroyed. (The zone was verified empty — 0 records, 0 rules, 0 tunnels.)
2. **Everything identifiable.** `lab-` prefix or `lab.<zone>` subdomain, plus
   `lab:` comments on records.
3. **Executable enforcement.** `policy/destroy_guard.rego` fails ANY plan
   that deletes a resource without a lab marker — wired into `tf-pr.yml` and
   `scripts/teardown.sh` (which is dry-run by default and aborts on one
   unmarked victim).
4. **No secret ever in git.** Tokens live in `~/.cf-lab-env` (outside the
   repo); `.gitignore` + pre-commit hooks + gitleaks block the rest. The repo
   is public — treat every commit as world-readable, because it is.
5. **Humans gate applies.** CI applies replay a reviewer-approved plan
   artifact inside a GitHub environment with a required reviewer.

## Setup from zero — the walkthrough

Steps marked **[YOU]** need the human (credentials, purchases, approvals).
Steps marked **[CLAUDE/CI]** are automated once the prerequisites exist.

### Step 1 — [YOU] GitHub CLI login (~2 min)

```bash
gh auth login
```

Choose **GitHub.com → HTTPS → Login with a web browser**. You're
`miroslavt-arch` in Chrome already, so it's two clicks.

### Step 2 — [CLAUDE] Repo creation (needs your explicit yes)

`gh repo create cf-terraform-lab --public --source . --push`, then tag
`v0.1.0` (scaffold commit) and `v0.2.0` (manage_settings commit) and flip
`envs/lab`'s module source to the tag ref — that's the Topic 7 pinning demo.
Public is required: environment protection rules and required reviewers are
free-tier features **only on public repos**.

### Step 3 — [YOU] Three Cloudflare API tokens (~10 min)

Dashboard → My Profile → API Tokens → Create Token → Custom token.
Zone scoping: **Include → Specific zone → zesty-beta.sxplab.com**.

| # | Name | Permissions | Env var |
|---|---|---|---|
| 1 | `lab-tf-plan-ro` | Zone:Read · DNS:Read · Zone Settings:Read · Zone WAF:Read (lab zone) + Account: Cloudflare Tunnel:Read, Account Filter Lists:Read | `CLOUDFLARE_API_TOKEN_PLAN` |
| 2 | `lab-tf-apply-rw` | Zone:Read · DNS:Edit · Zone Settings:Edit · Zone WAF:Edit (lab zone) + Account: Cloudflare Tunnel:Edit, Account Filter Lists:Edit, Access: Apps and Policies:Edit | `CLOUDFLARE_API_TOKEN` |
| 3 | `lab-audit-ro` | Account: Access: Audit Logs:Read *(fallback if rejected: Account Settings:Read)* | `CLOUDFLARE_AUDIT_TOKEN` |

### Step 4 — [YOU] R2 state backend (~5 min)

1. Dashboard → R2 Object Storage → **Create bucket** → name `lab-tfstate`,
   location Automatic.
2. R2 → **Manage R2 API Tokens** → Create token `lab-tfstate-token`,
   permission **Object Read & Write**, scope it to bucket `lab-tfstate`.
3. Note the **Access Key ID** and **Secret Access Key** it shows you once.

### Step 5 — [YOU] The env file (~2 min)

```bash
printf 'export CLOUDFLARE_ACCOUNT_ID="f40b69d8637a12568c6a62d218822384"\nexport LAB_ZONE="zesty-beta.sxplab.com"\nexport CLOUDFLARE_API_TOKEN_PLAN=""\nexport CLOUDFLARE_API_TOKEN=""\nexport CLOUDFLARE_AUDIT_TOKEN=""\nexport AWS_ACCESS_KEY_ID=""\nexport AWS_SECRET_ACCESS_KEY=""\n' > ~/.cf-lab-env && chmod 600 ~/.cf-lab-env && notepad "$(cygpath -w ~/.cf-lab-env)"
```

Paste the four secrets between the quotes **in Notepad** (never into chat,
never into any file inside the repo). Every script sources this file.

### Step 6 — [CLAUDE] Verification gate

Each token hits `GET /user/tokens/verify`; `gh auth status`; R2 access is
probed with a HEAD on the bucket. A green/red table is printed. Nothing
proceeds on red.

### Step 7 — [CLAUDE] First apply (plan shown first, zero destroys, your yes)

```bash
cd infra/envs/lab
cp lab.auto.tfvars.example lab.auto.tfvars
terraform init -backend-config=../../backends/lab.s3.tfbackend
terraform plan        # reviewed + OPA destroy-guard before any apply
terraform apply
```

Creates: 5 zone settings, 1 TXT record, the composed WAF ruleset (kill-switch
rules present but disabled). Expected: ~7 adds, 0 changes, **0 destroys**.

### Step 8 — [YOU, ~5 min] GitHub environments (Topic 20)

Repo → Settings → Environments:
- `lab-plan` — secrets: `CLOUDFLARE_API_TOKEN_PLAN`, `AWS_ACCESS_KEY_ID`,
  `AWS_SECRET_ACCESS_KEY`, `CLOUDFLARE_AUDIT_TOKEN`
- `lab-apply` — secrets: `CLOUDFLARE_API_TOKEN`, `AWS_ACCESS_KEY_ID`,
  `AWS_SECRET_ACCESS_KEY`; protection: **Required reviewers = you**,
  **Wait timer = 1 minute**
- Repo-level variables: `CF_ACCOUNT_ID`, `LAB_ZONE`, `LAB_ZONE_ID`

(Claude can do this via `gh api` with your approval instead — secrets pass
through the CLI from the env file without appearing in chat.)

### Step 9 — [YOU] Docker Desktop running (Topic 14 only)

Start Docker Desktop before the tunnel demo. Then:

```bash
cd infra/envs/lab
export TUNNEL_TOKEN=$(terraform output -raw tunnel_token)
docker compose -f tunnel-compose/docker-compose.yml up -d
```

### Step 10 — run the topics

Each topic = one script in `scripts/`, one runbook in `docs/runbooks/`:

| Topic | Demo | Needs |
|---|---|---|
| 7 | `demo-07-validation.sh` | nothing (offline) |
| 24 | `demo-24-unit-tests.sh` | nothing (offline) |
| 10 | `demo-10-fragment-lint.sh` | nothing (offline) |
| 9 | `demo-09-singleton-flap.sh` | apply token |
| 11 | `demo-11-arm.sh` | apply token + first apply done |
| 14 | `demo-14-ha-kill.sh`, `demo-14-rotate-tunnel.sh` | tunnel applied + Docker |
| 20 | `demo-20-stale-plan.sh` + a real PR through the pipeline | tokens + GitHub envs |
| 27 | `demo-27-make-drift.sh` | apply + audit tokens |
| 29 | `brownfield/seed-legacy.sh` then `demo-29-adopt.sh` | apply token |
| 32 | `demo-32-{phase,dual,list,noise}.sh` | apply token |

The 2-hour flow, timings, and fallbacks live in
[SESSION-RUNSHEET.md](SESSION-RUNSHEET.md). Removal: [TEARDOWN.md](TEARDOWN.md).

## Troubleshooting (failures actually hit while building)

- **`terraform test -filter=tests/unit.tftest.hcl` finds 0 tests on
  Windows** — Git Bash passes forward slashes; Terraform on Windows
  discovers `tests\unit.tftest.hcl`. Run bare `terraform test` (contract
  tests live in `tests/contract/`, a separate `-test-directory`, so the
  default run stays offline).
- **Ad-hoc `.tftest.hcl` files error "Module not installed"** — any new
  `module {}` source in a test file needs `terraform init` again (see
  `demo-07-validation.sh`).
- **pre-commit dies with `InvalidConfigError: mapping values are not
  allowed`** — a bash one-liner with colons in a YAML `entry:` needs
  quoting; the hooks live in `scripts/hooks/*.sh` instead.
- **`brownfield/adopt` fails validate before seeding** — `records.csv`
  doesn't exist yet; guarded with `fileexists()`.
- **Old Terraform 1.6.6 shadows 1.15.8 in Git Bash** — `~/bin/terraform.exe`
  (1.15.8) must precede `C:\Program Files\Terraform` in PATH.
- **Chrome screenshots fail (viewport 0×0)** — the Chrome window is
  minimized; un-minimize before dashboard walkthroughs in the session.
