# FIVE WALLS — a 90-minute live coding session

**The premise, said once at the start:**

> "Last session I showed you ten topics. This session I'm going to do something
> less tidy. I'm going to try to ship five bad changes to a live Cloudflare
> zone, and I'm going to fail every time — on purpose. Each failure happens at a
> different layer, and each one costs more than the last."
>
> "By the end you'll have a number for what it costs to catch a mistake in your
> editor versus catching it in code review versus catching it in production.
> That number is the entire argument for how this repo is built."

Everything below is typed live. No scripts for the first four walls — the point
is that the room watches you make an ordinary mistake and watches the system
notice.

**Same format as before:** `DO` is a keystroke or a click. Blockquotes are what
you say, in your own words.

---

## Timing

| | Segment | Minutes |
|---|---|---|
| 0:00 | Framing + setup | 8 |
| 0:08 | **Wall 1** — the type system | 8 |
| 0:16 | **Wall 2** — the validation block | 12 |
| 0:28 | **Wall 3** — pre-commit: a secret, then a security hole | 18 |
| 0:46 | **Wall 4** — the PR pipeline, where the team sees it | 24 |
| 1:10 | **Wall 5** — the human gate | 14 |
| 1:24 | The cost curve, and close | 6 |

Runs 90. To cut to 60: drop Wall 1 (least surprising), drop the destroy-guard
sub-segment in Wall 4, and shorten Wall 5 to the pause plus the approval.

---

## SETUP — before you share your screen

```bash
source ~/.cf-lab-env && cd "D:/Work/Claude/Shared Subnet Diagram/cf-terraform-lab" && git checkout main && git pull -q && clear
```

Font up 4–5 notches. Two windows: **VS Code** (you'll be typing) and **Chrome**
with three tabs — the repo, Actions, and the Cloudflare DNS page.

Confirm you're clean:

```bash
terraform -chdir=infra/envs/lab plan -input=false 2>&1 | grep -E "No changes|^Plan:"
```

---

# WALL 1 — the type system  ·  cost: seconds

### Say

> "First wall is the cheapest one there is. I'm going to write a DNS record with
> a type that doesn't exist, and I want you to notice how far that gets."

### Do

Open `infra/envs/lab/main.tf`. Find the `lab-hello` record. Change its type:

```
type    = "TXT"
```

to

```
type    = "SRV"
```

Then:

```bash
terraform -chdir=infra/envs/lab plan -input=false
```

### What lands

```
Error: Invalid value for variable

Record type must be one of A, AAAA, CNAME, TXT, MX. Anything more exotic
(SRV, CAA, ...) is deliberately out of scope for this module.
```

### Say

> "No network call happened. No credential was used. Terraform never spoke to
> Cloudflare. This is a `validation` block in the module's variable definition,
> and it ran locally in about a second."
>
> "And read the message — it tells you the allowed set *and* why SRV is
> excluded. A validation that just says 'invalid input' teaches nobody anything.
> Writing the sentence is the work."

### Fix and move on

Change it back to `TXT`. Re-run the plan, confirm `No changes`.

---

# WALL 2 — the validation block  ·  cost: seconds

### Say

> "Second wall. The last one was a typo — the type system catching a
> nonsense value. This one is different. I'm going to write something that is
> perfectly valid Terraform, perfectly valid DNS, and completely against the
> rules of this estate."

### Do

Same file. Rename the record key from `lab-hello` to `prod-api`:

```
"lab-hello" = {
```

to

```
"prod-api" = {
```

```bash
terraform -chdir=infra/envs/lab plan -input=false
```

### What lands

```
Error: Invalid value for variable

Every DNS record key must start with 'lab-'. This module refuses to create
records that are not trivially identifiable as lab-owned.
```

### Say — this is the important beat of the session

> "Nothing about `prod-api` is malformed. It's a fine name. The module rejected
> it because of a rule that exists only in this organisation."
>
> "This is the difference between a linter and a policy. A linter knows what
> Terraform allows. A policy knows what *you* allow. And the only way a policy
> survives contact with a deadline is if it's executable — if it exits non-zero.
> A rule in a wiki page is a hope. A rule in a `validation` block is a fact."
>
> "Notice also *where* the rule lives: in the module, not in the pipeline. That
> means it fires in my editor, before I commit, before CI, before anyone else's
> time is involved. Push your checks as far left as they'll go."

**If asked, "isn't that too strict? what if I legitimately need prod-api?"**

> "Then you change the module and someone reviews that change. That's the point
> — the exception becomes visible and deliberate instead of accidental. Right
> now the cost of the exception is a five-line PR. If the rule lived in a wiki,
> the cost would be zero and so would the rule."

### Fix and move on

Change it back to `lab-hello`. Confirm `No changes`.

---

# WALL 3 — pre-commit  ·  cost: seconds, and it never leaves your laptop

### Say

> "Third wall. It's late, the token isn't loading from the environment for some
> reason, and I do the thing everybody has done at least once."

### Do

Write the file the way it really happens — with your **actual** token, pulled
from the environment so it never appears in this document or in the repo:

```bash
printf 'provider "cloudflare" {
  api_token = "%s"
}
' "$CLOUDFLARE_API_TOKEN" > infra/envs/lab/oops.tf
```

**DO:** open the file in VS Code so the room can see a real token sitting in a
`.tf` file.

> "That is a live Cloudflare API token, in a Terraform file, in a repository
> that is **public**. This is the single most common way credentials leak, and
> it never happens on purpose — it happens at 6pm when the environment variable
> isn't loading and you just want the plan to run."

*(The scanner matches on real entropy, so a made-up token will not trip it —
that is why this uses the live one. It never reaches git: the commit is
refused, and the file is deleted at the end of the wall.)*

```bash
git checkout -b demo/five-walls
git add infra/envs/lab/oops.tf
git commit -m "temp: hardcode the token, will fix later"
```

### What lands

```
Detect hardcoded secrets.................................................Failed
Finding:     api_token = "REDACTED"
Secret:      REDACTED
```

**The commit does not exist.** Show them:

```bash
git log --oneline -1
```

— still the previous commit.

### Say

> "Look at two things. First, the commit was refused, so the secret never
> entered git history. That matters enormously, because git history is
> *forever* — if this had committed, removing it means rewriting history on a
> public repo and rotating the token anyway."
>
> "Second, look at what the tool printed. It found the secret and then
> **redacted it in its own output**. The tool that catches your secret is
> careful not to become the thing that leaks it. That's a detail somebody
> thought about, and it's the kind of detail that tells you a tool is serious."

**If asked, "what if I just use `--no-verify`?"**

> "Then it commits, and that's a deliberate choice you made with your fingers,
> which is a very different thing from an accident. The same check also runs in
> CI, so you'd be caught on the PR instead — one wall later, and now your whole
> team is watching. Which is exactly the cost curve I'm building toward."

### Then show pre-commit is more than a secret scanner

> "While we're at this layer — pre-commit isn't just grepping for tokens. Let me
> try a second thing, and this one is a feature request, not a mistake."

**DO:** open `infra/modules/waf-composed/rules/app-team.yaml` and add a rule:

```yaml
  - ref: lab_app_loadtest_skip
    description: "Skip the WAF for our load-test tool so runs stop failing"
    expression: 'http.host eq "__LAB_HOST__" and http.user_agent contains "loadtest"'
    action: skip
```

```bash
git add -A && git commit -m "app: skip the WAF for our load-test tool"
```

```
conftest on WAF fragments................................................Failed

app-team fragment: rule 'lab_app_loadtest_skip' uses action 'skip'. Skip
bypasses the incident and security rules that run above you — this action is
reserved for the security fragment.
```

> "Read what it says. Not 'invalid' — *skip bypasses the incident and security
> rules that run above you*."
>
> "Remember the ordering: incident, then security, then app. A `skip` in the app
> fragment doesn't skip the app team's rules. It skips **everything above it**.
> So during an incident, when we've armed the kill-switch to challenge all
> traffic, anyone sending a user-agent containing 'loadtest' walks straight
> through."
>
> "Nobody was being careless. They asked for a narrow exception and the
> mechanism they reached for was far wider than they realised. That is the
> normal case, not the exotic one. And the right answer is `log` — it gives them
> the visibility they actually wanted without the hole."

**DO:** open `policy/waf_fragments.rego`. Nine lines.

> "Nine lines of policy, running on my laptop, before this ever became anyone
> else's problem."

### Fix and move on

```bash
rm infra/envs/lab/oops.tf
git checkout -- infra/modules/waf-composed/rules/app-team.yaml
```

---

# WALL 4 — the PR pipeline  ·  cost: minutes, and the whole team sees it

This is the most important segment, because it answers the obvious question:
*if pre-commit catches everything, why do I need CI at all?*

### Say

> "Everything so far was caught on my laptop. So here's the fair question: if
> the checks all run locally, what is CI actually for?"
>
> "Here's what it's for. I'm going to make a change that passes **every single
> local check** — formatting, policy, secrets, all of it — and is still wrong."

### Do

Open `infra/modules/waf-composed/main.tf`, line 38. It reads:

```
ordered_rules = concat(local.render.incident, local.render.security, local.render.app)
```

Change the order — put the app team first:

```
ordered_rules = concat(local.render.app, local.render.incident, local.render.security)
```

> "That's a plausible edit. Maybe I'm debugging, maybe someone asked for their
> rules to be evaluated sooner. It is syntactically perfect."

**DO:** run the local checks in front of them and let them all pass:

```bash
terraform fmt -check infra/modules/waf-composed/main.tf && echo "fmt: PASSES"
conftest test --policy policy infra/modules/waf-composed/rules/ && echo "policy: PASSES"
```

Both pass. Now commit — and watch pre-commit pass too:

```bash
git add -A && git commit -m "waf: evaluate app rules first" && git push -u origin demo/five-walls
gh pr create --fill
```

> "Committed clean. Pushed. Every gate we've built so far said yes."

**DO:** open the PR in Chrome. Let `tf-pr` run. **Don't talk over it.**

### What lands

The `tier-one tests` job fails:

```
Error: Test assertion failed
  on tests/unit.tftest.hcl line 122, in run "fragment_ordering":

incident fragment is not first — ordering guarantee broken
```

```
Failure! 4 passed, 1 failed.
```

### Say

> "There it is. Not a formatting problem, not a policy violation — a **broken
> behavioural contract**. Every individual fragment was fine. What broke was the
> relationship *between* them."
>
> "And think about what I actually did. I put the app team's rules ahead of the
> incident rules. Which means during an incident, when we arm the kill-switch,
> an app rule could match first and the incident rule never runs. The
> kill-switch silently stops working. Nothing errors. Nothing looks wrong."
>
> "No linter can catch that, because there's nothing wrong with any single line.
> You need something that knows what the *system* is supposed to do. That's what
> a test is, and that's what CI is for."

**DO:** open `tests/unit.tftest.hcl` and show the assertion:

```hcl
assert {
  condition     = output.rule_order[0] == "lab_ir_elevated_challenge"
  error_message = "incident fragment is not first — ordering guarantee broken"
}
```

> "Two lines. That is the entire ordering guarantee from last session, written
> down in a form that runs. Somebody could have written 'incident rules must be
> first' in a design doc — and the design doc would still say that today, while
> production quietly did the opposite."
>
> "This is also why the test runs with a mocked provider and no credentials. It
> costs about a second, so it runs on every push, so it's still running a year
> from now when the person who wrote the ordering rule has left."

### Fix and move on

Put the order back and push again:

```bash
git checkout -- infra/modules/waf-composed/main.tf
```

Then make the change you actually wanted — a small, legitimate one:

**DO:** in `infra/envs/ci-demo/main.tf`, change the `demo_note` default to
something the room picks. Let someone in the audience choose the text.

```bash
git add -A && git commit -m "ci-demo: update the note" && git push
```

Watch `tf-pr` go green: tests pass, fmt passes, policy passes, plan runs with
the read-only token, destroy-guard passes, plan artifact uploaded.

### The one you hope never fires

**DO:** while the green run is up, point at the `OPA destroy guard` step.

> "One more thing on this run — the step that passed and that I hope you never
> see fail."

```bash
conftest test --policy policy --namespace destroy_guard policy/fixtures/destroy-prod-plan.json
```

> "It reads the JSON of the Terraform plan, finds every resource being
> destroyed, and fails if any of them lack the `lab-` marker:"

```
PLAN BLOCKED: cloudflare_dns_record.production_www would DESTROY
'www.customer-prod.com' which does not carry the lab- prefix. The lab never
destroys pre-existing resources. If this is intentional, it needs an explicit
human decision, not a pipeline run.
```

> "Terraform will destroy anything you tell it to, cheerfully. This is the layer
> that says: not from a pipeline run, and not without a human explicitly
> deciding."

---

# WALL 5 — the human gate  ·  cost: minutes, plus a person

### Say

> "Fifth wall. The change is now correct. Tests pass, policy passes, the plan is
> clean. Everything is green. And it still cannot reach production on its own."

### Do

The PR is green. Grab the run id and SHA from the PR, then:

```bash
gh workflow run tf-apply.yml -f plan_run_id=<RUN_ID> -f sha=<SHA>
```

**DO:** open the run in Actions. **Stop talking.** Let them look at it.

### Say

> "The job isn't slow. It's *stopped*. It has no write credential — the token
> lives inside a GitHub environment, and the job is not handed that environment
> until a named human approves. There's also a one-minute timer, which exists
> purely to create an 'oh wait, stop' window."
>
> "And what it will apply is not a fresh plan. It downloads the plan artifact
> from the PR run — keyed by commit SHA — and runs `terraform apply` against
> that file. What I approved is byte-for-byte what executes."

**DO:** approve it. Review deployments → tick `lab-apply` → Approve and deploy.

Then show it's real:

```bash
bash scripts/prove-it-is-real.sh
```

### Say

> "That's a public resolver and the Cloudflare API confirming what this repo
> says. Not my terminal talking to itself."

---

# THE COST CURVE — close with this

**DO:** put this on screen, or just say the numbers.

| Wall | Caught by | Cost when it fires |
|---|---|---|
| 1 | the type system | **seconds** — one person, no context switch |
| 2 | a validation block | **seconds** — same |
| 3 | pre-commit | **seconds** — and it never entered git history |
| 4 | the contract tests in CI | **minutes to hours** — a review cycle, the whole team sees it |
| 5 | a human at the gate | **minutes, plus someone's attention** |
| — | **production** | **hours to days**, at 3am, during an incident |

### Say

> "Every wall does roughly the same job: it says no. What changes is the price.
> Each layer down costs about ten times the one above it, and the last one —
> finding out in production — costs so much more than the rest that it's not
> really on the same scale."
>
> "So the design rule falls out on its own: **push every check as far left as it
> will go.** If a rule can live in a validation block, it should not live in
> CI. If it can live in pre-commit, it should not live in code review. You are
> not trying to have more gates. You are trying to have the *cheapest possible*
> gate for each class of mistake."
>
> "And notice what all five had in common. Not one of them was a document.
> Every single one exits non-zero. A policy that isn't a check is a hope, and
> hope doesn't survive a deadline."

**Final line:**

> "The five things I tried to do today were: a typo, a naming violation, a
> leaked credential, a security hole disguised as a feature request, and a
> perfectly good change. The system treated all five the same way — it read
> them, decided, and told me why. Four times it said no. Once it asked a human.
> That's the whole system."

---

# RESET — after the session

```bash
gh pr close demo/five-walls --delete-branch
git checkout main
bash scripts/trigger/99-reset.sh
```

---

# IF SOMETHING GOES WRONG

| Symptom | Do this |
|---|---|
| A wall doesn't fire | Say "that's worth looking at" and read the output together. You're demonstrating a system that explains itself — use it |
| `source: not recognized` | PowerShell. Switch to Git Bash |
| Plan says `1 to change` | You left an edit in. `git checkout -- infra/envs/lab/main.tf` |
| Pre-commit blocks a fix you *want* | `git commit --no-verify` — and narrate that you're doing it deliberately, which is exactly the point of Wall 3 |
| The PR pipeline is slow | Talk through `policy/waf_fragments.rego` while it runs. Never watch a spinner in silence |

# WHAT'S REHEARSED VS LIVE

Walls 1, 2 and 3 are **verified** — the exact errors above are what they print.
Wall 4's policy failure is verified against the same fixture. Wall 5 has been
run end to end.

The one thing I'd rehearse once before delivering: **Wall 4's push**, because
it's the only segment where you're waiting on GitHub in front of the room.
Know how long `tf-pr` takes on this repo so you can fill the gap deliberately.
