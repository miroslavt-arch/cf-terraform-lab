# GO-LIVE CHEAT SHEET

Everything below is **verified working** as of 2026-08-21 09:0x UTC.
Open two windows: a terminal in the repo root, and Chrome on the repo + the
Cloudflare dashboard.

```bash
source ~/.cf-lab-env
cd "D:/Work/Claude/Shared Subnet Diagram/cf-terraform-lab"
```

---

## THE PIPELINE — Topic 20 (do this first, it needs a 1-minute timer)

**PR #2 is already open and its plan has already passed.**
https://github.com/miroslavt-arch/cf-terraform-lab/pull/2

1. **Show the PR comment** — the plan, posted by CI, with the artifact name
   `tfplan-cbc0a374...` = the commit SHA. Say: *"That artifact is what my
   reviewer approves. The apply job replays it byte for byte — it never
   re-plans."*

2. **Show the read-only token** — Settings → Environments → `lab-plan`.
   Say: *"The job that produced this plan physically cannot write to
   Cloudflare. Planning is safe by construction, not by policy."*

3. **Fire the apply:**
   ```bash
   gh workflow run tf-apply.yml --repo miroslavt-arch/cf-terraform-lab \
     -f plan_run_id=32466152247 \
     -f sha=cbc0a3746ffa6db94127353df0706375bfc877af
   ```

4. **Open the Actions tab.** The job says **waiting**. Show
   Settings → Environments → `lab-apply`: 1-minute wait timer + required
   reviewer. Say: *"Nothing is running. The write token is inside this
   environment and the job hasn't been given it yet."*

5. **Approve it** (button on the run page). Watch it apply.

6. **Show the result** in the Cloudflare dashboard — DNS →
   `lab-ci-demo.lab.gracious-binary.sxplab.com`, content
   *"applied live, after a human approved the plan"*.

7. **Then the invariant underneath it:**
   ```bash
   bash scripts/demo-20-stale-plan.sh
   ```
   Ends with Terraform's own refusal: **`Saved plan is stale`**.

### Reset for a second delivery
```bash
zid=9e9f552861413a5b624357be77e3516b
rid=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/$zid/dns_records?name=lab-ci-demo.lab.$LAB_ZONE" | jq -r '.result[0].id')
curl -s -X DELETE -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/$zid/dns_records/$rid" >/dev/null
gh pr close 2 --delete-branch    # then open a fresh branch+PR the same way
```

---

## THE REST — all verified, all local, all fast

| # | Command | The line to say |
|---|---|---|
| 24 | `bash scripts/demo-24-unit-tests.sh` | "No token, no network, 0.36 seconds. Nobody argues about running these on every PR." |
| 7 | `bash scripts/demo-07-validation.sh` | "That error was written by the module author and fired at plan time." |
| 7 | `git diff v0.1.0 v0.2.0 -- infra/modules/zone-baseline/variables.tf` | "The whole upgrade: one optional input. Optional means existing callers get a zero-change plan." |
| 10 | `bash scripts/demo-10-fragment-lint.sh` | "The concat line is the org chart. The lint lands on the offending team's PR." |
| 9 | `bash scripts/demo-09-singleton-flap.sh` | "Both pipelines green. Value flaps forever. Singletons need one owner." |
| 11 | `bash scripts/demo-11-arm.sh` | "6 seconds from incident declared to live at the edge — and I didn't write a firewall rule, I flipped one word." |
| 29 | `bash scripts/demo-29-adopt.sh` | "5 to import, **0 changed, 0 destroyed**, then 'No changes'. That sentence is the certificate." |
| 32 | `bash scripts/demo-32-noise.sh` | "I wrote the trailing dot like every DNS textbook says. This pipeline is never green again." |
| 32 | `bash scripts/demo-32-dual.sh` | "Two roots, one record. Nobody errors. Both teams think the other is drifting." |
| 32 | `bash scripts/demo-32-phase.sh` | "The API refuses the second claimant — and that loud error is the healthy outcome." |
| 27 | `bash scripts/demo-27-make-drift.sh` | "Exit code 2 is the detector." *(attribution table needs the audit-token fix — see below)* |

**Live proof the reminder workflow works:** Actions →
`killswitch-reminder` has been passing hourly on schedule all night.

---

## KNOWN GAPS — say these out loud rather than being caught

1. **Topic 14 (tunnels) is not running.** The `lab-tf-apply-rw` token can read
   tunnels but not create them — `POST /cfd_tunnel` returns
   *Authentication error*. Fix: edit the token, ensure **Account → Cloudflare
   Tunnel → Edit** is present, then:
   ```bash
   sed -i 's/^enable_tunnel.*/enable_tunnel = true/' infra/envs/lab/lab.auto.tfvars
   terraform -chdir=infra/envs/lab apply
   cd infra/envs/lab && export TUNNEL_TOKEN=$(terraform output -raw tunnel_token)
   docker compose -f tunnel-compose/docker-compose.yml up -d
   ```
   Until then, teach Topic 14 from `modules/tunnel-site/main.tf` — ingress
   ordering with the catch-all last, `config_src = "cloudflare"`, and the
   two-step rotation in `docs/runbooks/topic-14.md`.

2. **Topic 27 attribution.** Drift *detection* works. The audit-log join needs
   **Account → Account Settings → Read** added to `lab-audit-ro`.

3. **No remote state.** `infra/envs/lab` uses local state; the CI pipeline uses
   `infra/envs/ci-demo`, which owns one not-yet-existing record so empty state
   is correct. That is an honest teaching point: *"remote state is what you'd
   add next, and here's exactly why."* The `drift` and `contract-tests`
   workflows are `workflow_dispatch`-only for the same reason.
