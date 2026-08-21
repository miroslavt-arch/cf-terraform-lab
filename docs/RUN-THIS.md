# RUN THIS — the demo, start to finish

Two windows only: **Chrome** (5 tabs, already open in order) and **one
terminal**. Every step says where you are and exactly what to do.

**Tabs, left to right — do not reorder them:**

| Tab | What it is |
|---|---|
| **1** | Pull request #3 |
| **2** | Actions |
| **3** | Settings → Environments |
| **4** | Cloudflare DNS records |
| **5** | Code: `waf-composed/main.tf` |

**Terminal — paste this once, before you share your screen:**
```bash
source ~/.cf-lab-env && cd "D:/Work/Claude/Shared Subnet Diagram/cf-terraform-lab" && clear
```

---

## TIMING AT A GLANCE

| Time | Topic | Where |
|---|---|---|
| 0:00 | Opening | Tab 5 |
| 0:03 | **Topic 20** — the human gate | Tabs 1→3→2→4 |
| 0:21 | **Topic 24** — tests | Terminal |
| 0:26 | **Topic 7** — module contract | Terminal |
| 0:33 | **Topic 10** — WAF composition | Terminal + Tab 5 |
| 0:40 | **Topic 9** — singleton ownership | Terminal |
| 0:46 | **Topic 11** — kill switches | Terminal + Tab 2 |
| 0:53 | **Topic 29** — brownfield adoption | Terminal |
| 1:00 | **Topic 32** — sharp edges | Terminal |
| 1:09 | **Topic 27** — drift | Terminal |
| 1:15 | **Topic 14** — tunnels (walkthrough) | Tab 5 |
| 1:20 | Close | — |

Short on time? Cut Topic 14 first, then one of the two Topic 32 demos.

---

# 0:00 — OPENING (3 min)

**Tab 5.**

> "Everything you'll see runs against a real Cloudflare zone with real
> Terraform and real GitHub Actions. Ten topics. Four of them are failures on
> purpose — I break things deliberately, because the failures are the lesson.
> Every resource this lab touches is named `lab-` something, and a policy
> refuses any plan that would destroy anything without that prefix. That's why
> it's safe to do this live."

---

# 0:03 — TOPIC 20 — THE HUMAN GATE (18 min)

*The one with a timer in it. Do it first while everyone is fresh.*

### Step 1 — the plan CI wrote  → **Tab 1**
- Scroll to the comment **"Terraform plan for 9da72890"**
- Click the triangle **plan output** to expand

> "I didn't run this plan. A GitHub Action ran it when I opened the pull
> request, and posted it back here as a comment."

- Point at the line **Artifact: tfplan-9da72890…**

> "The artifact is named after the commit SHA. That file is what my reviewer
> approves. Remember it — it matters in ninety seconds."

### Step 2 — the planner cannot write  → **Tab 3**
- Click **lab-plan**
- Point at **Environment secrets**: one entry, `CLOUDFLARE_API_TOKEN_PLAN`

> "The job that made that plan runs here. The only Cloudflare credential it can
> see is read-only. It's not that we trust the plan job — the plan job is
> incapable of writing."

### Step 3 — the gate  → **Tab 3**
- Click **Environments** in the breadcrumb, then **lab-apply**
- Point at **Required reviewers** (your name), **Wait timer** (1 minute)
- Scroll down, point at **Environment secrets**: `CLOUDFLARE_API_TOKEN`

> "This is the environment that can write. Reviewer, timer, and the write
> token — all in the same box. A job doesn't get the token until it gets
> through the gate."

### Step 4 — fire it  → **TERMINAL**
```bash
gh workflow run tf-apply.yml --repo miroslavt-arch/cf-terraform-lab -f plan_run_id=32468491504 -f sha=9da72890087d6e95dbf31df09178935132e4a586
```

> "Two inputs: which run produced the plan, and which commit it was for."

### Step 5 — watch it refuse to start  → **Tab 2**
- Press **F5**, click the top run (**tf-apply**)
- Point at the yellow **Waiting** and the **Deployment protection rules** box

> "Nothing is running. The timer is counting, then it needs my approval. If I
> walked away right now, nothing would ever reach Cloudflare."

### Step 6 — fill the minute  → **TERMINAL**
```bash
bash scripts/demo-20-stale-plan.sh
```
- When the red block appears, stop talking. Point at **Saved plan is stale**

> "I saved a plan. Someone changed a record behind my back. Terraform refused
> to apply the plan my reviewer approved. Process can be skipped. This can't."

### Step 7 — approve  → **Tab 2**
- Click **Review deployments**
- Tick **lab-apply**
- Click **Approve and deploy**
- Click into the job, expand **download the EXACT plan artifact**, then
  **apply the pinned plan — NOT a fresh plan**

> "It downloaded the artifact. It did not re-plan. What was approved is what
> executed."

### Step 8 — the result  → **Tab 4**
- Press **F5**, point at **lab-ci-demo**

> "A human approved a plan, and a machine applied exactly that plan. That's the
> whole pattern."

---

# 0:21 — TOPIC 24 — TESTS THAT COST NOTHING (5 min)

**TERMINAL**
```bash
bash scripts/demo-24-unit-tests.sh
```
- Point at **real 0m0.3xxs**

> "No token. No network. Five tests in a third of a second. There is no meeting
> where anyone argues about whether we can afford to run these on every pull
> request."

---

# 0:26 — TOPIC 7 — THE MODULE IS A CONTRACT (7 min)

**TERMINAL**
```bash
bash scripts/demo-07-validation.sh
```
- Point at the red **Invalid value for variable**

> "That message was written by the module author. It fired at plan time, in my
> terminal, before anything touched Cloudflare. Validation is documentation
> that executes."

**TERMINAL**
```bash
git diff v0.1.0 v0.2.0 -- infra/modules/zone-baseline/variables.tf
```

> "Consumers pin a tag, not a branch. That's the whole upgrade between two
> versions: one optional input. Optional means every existing caller upgrades
> with a zero-change plan."

---

# 0:33 — TOPIC 10 — WAF COMPOSITION (7 min)

**TERMINAL**
```bash
bash scripts/demo-10-fragment-lint.sh
```
- Point at the two red **FAIL** lines

> "Three teams contribute fragments to one ruleset. The app team just tried to
> ship a skip action, and the lint stopped it with a message that explains why.
> That failure lands on their pull request, not on the merged ruleset."

**Tab 5** — point at the line `ordered_rules = concat(...)`

> "That single line is the org chart: incident, then security, then app. No
> team's edit can reorder another team's rules."

---

# 0:40 — TOPIC 9 — SINGLETON OWNERSHIP (6 min)

**TERMINAL**
```bash
bash scripts/demo-09-singleton-flap.sh
```
- Point at the values as they print: `high` → `essentially_off` → `high`

> "Two Terraform roots both believe they own this one setting. Neither errors.
> Both pipelines are green. The value flaps forever, and what the dashboard
> shows depends on who applied last."

---

# 0:46 — TOPIC 11 — KILL SWITCHES (7 min)

**TERMINAL**
```bash
bash scripts/demo-11-arm.sh
```
- Point at **ARMED at the edge in 6 seconds**

> "Incident declared. I did not write a firewall rule just now. That rule was
> written months ago, reviewed in daylight, and has been sitting in the ruleset
> disabled ever since. I flipped one word in a variables file. Six seconds from
> declaration to live at the edge — and six seconds back."

**Tab 2** — click **killswitch-reminder** in the left sidebar
- Point at the column of green checks going back hours

> "That has run every hour all night without me. It asks the Cloudflare API
> whether any kill switch is still armed, and fails loudly for as long as one
> is. It checks reality, not intent."

---

# 0:53 — TOPIC 29 — BROWNFIELD ADOPTION (7 min)

**TERMINAL**
```bash
bash scripts/demo-29-adopt.sh
```
- Point at **Plan: 5 to import, 0 to add, 0 to change, 0 to destroy**
- Then at **No changes** at the end

> "Six resources Terraform had never heard of, made by raw API calls the way a
> dashboard user would. Zero changed. Zero destroyed. And the next plan says No
> changes. That sentence is the certificate that adoption touched nothing —
> and nobody refactors until they see it."

---

# 1:00 — TOPIC 32 — SHARP EDGES (9 min)

**TERMINAL**
```bash
bash scripts/demo-32-noise.sh
```
- Point at the repeated **Plan: 0 to add, 1 to change** lines

> "I wrote a CNAME target with a trailing dot, the way every DNS textbook says
> to. Cloudflare stores it without. Applying doesn't fix it — apply, still
> dirty; apply again, still dirty. This pipeline is never green again."

> "And the tempting fix, ignore_changes, is worse. You stop managing that field
> entirely, so a real repoint of this record would also go unnoticed. You'd
> trade a cosmetic itch for blindness on the field that matters most."

**TERMINAL**
```bash
bash scripts/demo-32-dual.sh
```

> "Two roots, one DNS record. Nobody errors, ever. Each team sees the other as
> drift. Both pipelines stay green while the value flips back and forth
> forever."

---

# 1:09 — TOPIC 27 — DRIFT (6 min)

**TERMINAL**
```bash
bash scripts/demo-27-make-drift.sh
```
- Point at **exit code 2 — drift detected**

> "One flag is the whole detector: plan, detailed exit code, two means drift.
> But 'something changed' is a useless alert, so the report joins the drifted
> resource against the Cloudflare audit log to name the human who did it."

> "And detection is the consolation prize. The real fix is structural: make
> humans read-only in the dashboard, and let only the pipeline's scoped token
> write."

---

# 1:15 — TOPIC 14 — TUNNELS (5 min, walkthrough — nothing to run)

**Tab 5** — change the URL to:
`https://github.com/miroslavt-arch/cf-terraform-lab/blob/main/infra/modules/tunnel-site/main.tf`

- Point at `config_src = "cloudflare"`

> "The ingress config lives in Cloudflare under Terraform's control, not in a
> file on a box. That's what makes the connectors stateless — you get high
> availability by simply running two of them and killing either one."

- Point at the `ingress` list, and the final entry `http_status:404`

> "First match wins, and the catch-all has to be last. The module enforces that
> structurally rather than hoping someone remembers."

> "Rotation is two steps: bring up a parallel tunnel, then cut the DNS record
> over in place — because the environment owns that record, not the module. The
> naive version destroys the tunnel your DNS is currently pointing at."

> "I'm not running it live today: the token in this lab can read tunnels but
> not create them."

---

# 1:20 — CLOSE

> "Four of the things I showed you were failures on purpose. Phase ownership,
> dual writers, the flapping setting, the never-settling plan. They're the same
> disease at different altitudes: a shared thing with two owners. The API
> referees loudly sometimes and not at all other times — and the quiet ones are
> the expensive ones."

---

# IF YOU DELIVER IT AGAIN — RESET

**TERMINAL** — paste the whole block:
```bash
source ~/.cf-lab-env
cd "D:/Work/Claude/Shared Subnet Diagram/cf-terraform-lab"
zid=9e9f552861413a5b624357be77e3516b
rid=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/zones/$zid/dns_records?name=lab-ci-demo.lab.$LAB_ZONE" | jq -r '.result[0].id')
curl -s -X DELETE -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/zones/$zid/dns_records/$rid" >/dev/null
git checkout -- infra/envs/lab/main.tf 2>/dev/null
bash scripts/arm-killswitch.sh none >/dev/null
terraform -chdir=infra/envs/lab apply -auto-approve -input=false >/dev/null
git checkout main -q && git checkout -qb demo/run2
sed -i 's|default     = ".*"|default     = "second delivery"|' infra/envs/ci-demo/main.tf
git commit -qam "demo: run 2" && git push -qu origin demo/run2 && gh pr create --fill
echo "reset done — wait for the plan to go green, then run the line below"
```

Then get the two values for Step 4:
```bash
gh run list --limit 1 --json databaseId,headSha --jq '.[]|"plan_run_id=\(.databaseId) sha=\(.headSha)"'
```
