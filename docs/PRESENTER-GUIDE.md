# PRESENTER GUIDE - the full lab, ten topics

Everything here has been run against the live account. Zone
`zesty-beta.sxplab.com`, account `f40b69d8637a12568c6a62d218822384`,
repo https://github.com/miroslavt-arch/cf-terraform-lab

- **DO** = a click or a paste. Never improvise a command; these are exact.
- Blockquotes are narration. Say them in your own words, do not read them out.
- **If asked** = the questions that actually come up.

---

## WHICH TERMINAL - read this first

**Every command here is Git Bash. None of them work in PowerShell.** If you
paste them into PowerShell you get `The term 'source' is not recognized`, and
nothing else is wrong; the shell is.

In VS Code: Terminal, New Terminal, then the **v** beside the `+`, and choose
**Git Bash**. You are in the right shell when the prompt ends in `$` and shows
forward slashes.

**Run this once, before you share your screen:**
```bash
source ~/.cf-lab-env && cd "D:/Work/Claude/Shared Subnet Diagram/cf-terraform-lab" && clear
```

Then make the font large: Ctrl and `+`, four or five times.

## THREE CHROME TABS, left to right

| Tab | URL |
|---|---|
| **1** | https://github.com/miroslavt-arch/cf-terraform-lab |
| **2** | https://github.com/miroslavt-arch/cf-terraform-lab/actions/workflows/demo.yml |
| **3** | https://dash.cloudflare.com/f40b69d8637a12568c6a62d218822384/zesty-beta.sxplab.com/dns/records |

## PRE-FLIGHT (self-contained, safe in a fresh terminal)

```bash
source ~/.cf-lab-env && cd "D:/Work/Claude/Shared Subnet Diagram/cf-terraform-lab"
terraform -chdir=infra/envs/lab plan -input=false 2>&1 | grep -E "No changes|^Plan:"
terraform -chdir=brownfield/adopt plan -input=false -var zone_id=6fe522935f35ff5b7e1a049c1a90d11e -var zone_name=$LAB_ZONE 2>&1 | grep -E "No changes|^Plan:"
curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/zones?name=$LAB_ZONE" | jq -r '.result[0].status'
terraform test 2>&1 | tail -1
```
Expect exactly: `No changes`, `No changes`, `active`, `5 passed, 0 failed`.

If a plan says `Plan: 0 to add, 1 to change`, a previous run was interrupted.
Run the RESET block at the end, then re-check.

---

## HOW TO RUN ANY TOPIC - two routes, pick one and stay with it

**Route A, the GitHub console. Recommended when presenting.**

Tab 2, **Run workflow**, choose the topic, **Run workflow**. The job pauses at
the `lab-apply` gate. Click **Review deployments**, tick **lab-apply**, then
**Approve and deploy**. Output renders in the job summary, with links straight
into the Cloudflare dashboard.

That pause is worth narrating rather than apologising for:

> "Even my demo runs do not get a write credential until a human approves them.
> That is the same gate a production change goes through, and you are watching
> it work."

**Route B, Git Bash.** The commands under each topic. Faster, no approval
click, but the room watches a terminal instead of a console.

Three topics use a slightly different script in CI, because a GitHub runner has
no local Terraform state: **11** imports the live ruleset rather than editing
tfvars, **20** owns one record end to end, and **27** creates its own record
rather than drifting one the lab environment owns. Same mechanism either way.

## THE TWELVE MENU ENTRIES

| Menu entry | Topic | Live? |
|---|---|---|
| `topic-07-module-design` | 7 | offline |
| `topic-09-singleton-ownership` | 9 | live |
| `topic-10-waf-composition` | 10 | offline |
| `topic-11-kill-switch` | 11 | live |
| `topic-14-tunnel-design-walkthrough` | 14 | code walkthrough only |
| `topic-20-stale-plan-invariant` | 20 | live |
| `topic-24-terraform-test` | 24 | offline |
| `topic-27-drift-detection` | 27 | live |
| `topic-29-brownfield-adoption` | 29 | live |
| `topic-32-plan-noise` | 32 | live |
| `topic-32-dual-writers` | 32 | live |
| `topic-32-phase-ownership` | 32 | live |

All twelve verified green on this account.

---

## OPENING (4 minutes)

**Tab 1**, the repo root. **DO:** point at the directories as you name them.

> "Quick orientation. `infra/modules` holds the reusable building blocks.
> `infra/envs` is the root that actually applies, and environments are
> directories here rather than Terraform workspaces. `policy` is Open Policy
> Agent rules that run against plan output. `brownfield` is a legacy estate I
> built by hand so we can adopt it. `demos` is deliberately broken setups.
> `scripts` is one runnable demo per topic."
>
> "Everything is real. A real Cloudflare zone, real Terraform state, real
> Actions runs. Nothing is pre-recorded. If something fails, that is a genuine
> failure and we will look at it together."
>
> "Several of these topics are failures on purpose. In infrastructure code the
> failure modes are the curriculum. Anyone can show you a working
> `terraform apply`. The useful knowledge is what happens when two teams both
> think they own the same resource, or when the API quietly rewrites what you
> asked for."

**DO:** click into `policy`, then `destroy_guard.rego`.

> "Before I touch a live account in front of you, the safety model, shown
> rather than promised. Every resource this lab creates is named `lab-`
> something. This file reads the JSON of a Terraform plan, finds everything
> being destroyed, and fails the plan if any of it lacks that marker."
>
> "That pattern is worth stealing on its own. If your safety rule lives in a
> runbook or a wiki page, it is not a safety rule, it is a hope. If it exits
> non-zero, it is a rule. That distinction runs through every topic today."

**DO:** breadcrumb back to the repo root.

---

# TOPIC 7 - Module design: thin interfaces, validation, version tags, outputs as contracts

### Why this matters

> Think about the last shared module someone handed you. Fifteen inputs, a README that documents nine of them, and the tenth is the one you needed. You guess, you apply, and somewhere around the third resource the provider rejects your value. The run stops with three things created and two not. You were not reckless. You passed a TTL the module never intended to accept, and nothing told you until the API said no.
>
> The obvious fix is to write it down. Put the rules in the README, mention it in review. That fails for a boring reason. The README is a different file from the code and it drifts within a sprint, and a reviewer catches it only when they happen to remember. Neither one is checked while the change is still just text.
>
> There is a second half to this. Once the module is good you want to improve it, and every caller pointing at main gets your improvement on their next run, whether they were ready or not.

### Run it

**DO:** In Actions, choose demo (run a topic), then `topic-07-module-design`.

**DO:** In Git Bash, run `bash scripts/demo-07-validation.sh`.

**DO:** Then run `git diff v0.1.0 v0.2.0 -- infra/modules/zone-baseline/variables.tf`.

### What just happened

> The bad input never reached Cloudflare. It failed at plan, and the message on screen is the module's own: "Error: Invalid value for variable / Every DNS record key must start with lab-...". Terraform prints the header; the sentence after it was written in the module, not by the provider. It comes from one of four validation blocks in `zone-baseline/variables.tf`, each with its own message: the `lab-` prefix on record keys, a closed set of record types, a TTL of 1 or 60 to 86400, and an allow-list for `settings_overrides`. Distinct messages mean the caller learns which rule they broke, not that something somewhere is invalid.
>
> Then the good input passes 5/5. Notice how narrow the surface is. At v0.1.0 there is exactly one variable, `zones`, a `map(object)` built on `optional()` defaults, with a nested optional `metadata` object that defaults to an empty object. One input, not fifteen. Everything a caller may say, they say inside that shape, and those four blocks decide what is sayable. `outputs.tf` is the other half of the contract: `zone_ids`, `record_fqdns`, `settings_applied`, and nothing else that downstream code is allowed to depend on. `README.md` is generated by terraform-docs and wired into pre-commit, so the input documentation is regenerated from `variables.tf` rather than maintained by hand.
>
> The tag diff is +6 lines. One new input, `manage_settings`, optional, with a default. Nothing existing changed shape, so nobody on v0.1.0 has to move, and `infra/envs/lab/main.tf` pins the module by git tag at `ref=v0.1.0`, so nobody moves by accident. Both tags plan clean, "No changes", against the live estate.

### The point

> Make the interface the smallest thing you can get away with, and let the module check its own inputs in its own words. Validation that lives beside the variable travels with the module into every repo that calls it. A README cannot travel and a reviewer cannot travel.
>
> Then version it and make callers pin to a tag. That turns "I improved the module" into a decision each team makes on its own schedule, instead of a surprise in somebody's Monday plan. Additive, optional, defaulted changes are cheap. Removing an output or making an input required is a different conversation.

### If asked

- **"Why not put these checks in CI instead?"** CI runs in the module's repo. The validation runs wherever the module is called, for every consumer, including the team that never looks at your pipeline.
- **"Do `optional()` defaults just hide mistakes?"** They set the shape so callers can omit what they do not care about. The four validation blocks constrain the values. Shape and values are separate jobs.
- **"What about a change that is not additive?"** v0.2.0 is the cheap case: one optional input with a default, six lines. Removing an output or making an input required is not that. Cut a new tag and let callers move when they choose.
- **"Why pin to a tag rather than track main?"** Because on main your plan changes when someone else merges. Pinned at `ref=v0.1.0`, the module in your plan changes only when you move the pin.

---

# TOPIC 9 - The settings baseline: singleton ownership and the allow-listed override door

### Why this matters (the problem, before any command)

> Picture two Terraform roots in your own estate. The security team owns one, and before a campaign they set the zone's security level to high. The web team owns another, with its own state and its own pipeline, and they set the same zone's security level to essentially_off because a bot check was breaking a checkout flow. Both pipelines are green. Both have been green for months. The zone's real posture is simply whichever pipeline ran most recently.
>
> Nobody catches this because zone settings are singletons. There is exactly one value per zone. You cannot create one and you cannot delete one, you can only set it. So there is no name collision for Terraform to trip over, no already exists error, nothing for a pipeline to fail on. Every apply is a valid write, and each root's state file reports, quite honestly, that it got what it asked for.
>
> That is why the usual reflexes do not help. Putting ignore_changes on the resource only stops your root from correcting the value, it does nothing to stop the other root from writing it. Splitting the resource per team is not possible, because there is only one thing to split. And a wiki page asking people to check before touching security level is not a control, it is a hope.

### Run it

- DO: Run **topic-09-singleton-ownership** from the Actions list.
- DO: Or, in Git Bash, run `bash scripts/demo-09-singleton-flap.sh`.

### What just happened

> Follow the security_level value down the screen. It reads high, then essentially_off, then high again. Say that out loud, because the important part is the second half of the sentence. There were no errors anywhere. Nothing warned anyone, nothing blocked anything, and both roots would report success to whoever is watching their pipeline.
>
> The two roots doing this are demos/singleton-conflict/root-a and root-b. They each declare security_level with a different value, and they each keep their own local state. Neither one is misconfigured. They are both correct, in isolation, which is exactly the failure mode. Last writer wins, quietly, and the winner changes with the schedule.
>
> Now look at the other half of the demo, zone-baseline/main.tf. The baseline is a locals map of five settings, held in one place with one owner. The resources use for_each over merge(baseline, overrides), so there is one cloudflare_zone_setting per setting rather than one big blob. That is why a plan names exactly which setting is about to change, instead of showing you a single resource updating in place and leaving you to guess what moved.
>
> The door for exceptions is a validation block. Only security_level, browser_check and challenge_ttl may be overridden. Ask for anything else and it fails at plan, with a message that tells the requester where that request actually belongs.

### The point

> Where a resource is a singleton, your tooling cannot protect you, because there is no conflict for it to detect. Ownership has to be structural. One map, one owner, one place the value is decided, and a narrow list of things a consumer is allowed to move.
>
> The allow list matters as much as the baseline. An override door with no limit is just a second owner with extra steps. Name the three settings you are willing to negotiate, fail everything else at plan time, and say in the error message where that conversation should happen instead.

### If asked

- **Can we not just use ignore_changes on one side?** No. It stops your root from correcting drift, it does not stop the other root from setting the value. You get the same flap, and now you cannot see it in your own plan either.

- **What if a team needs a setting that is not one of the three?** The plan fails and the message explains where that request belongs. That is the intended path. The answer is to change the baseline for everyone, deliberately, not to widen the door quietly.

- **What happens when a team removes their override?** Where the baseline carries that setting, nothing is destroyed: these settings have no create or delete, only set, so the merge falls back to the baseline value and the next apply writes it. Be precise about the one case that differs. An allow-listed setting that the five-setting baseline does not include has no baseline value to fall back to, so removing that override takes the key out of the merged map rather than reverting it.

- **Why one resource per setting rather than one block?** Because for_each over the merged map makes the plan name the exact setting that is changing. A reviewer sees which of the five moved, without reading the diff twice.

---

# TOPIC 10 - WAF ruleset composition: per-team fragments, deterministic ordering, per-fragment linting

### Why this matters

> Picture one Cloudflare zone with three teams writing rules on it. The incident team needs a block at the very top during an active attack. The security team owns the /admin protections that have been in place for years. The app team is shipping a partner integration and needs an allow rule. All three edit the same Terraform file, and one Friday the app team's allow lands above the incident block. Attack traffic matches the allow first, the block never runs, and nobody notices until the next report.

> The obvious fix is to split the file so each team edits its own. That ends the merge conflicts and does nothing about ordering, because the order becomes whatever the concatenation happened to produce that week, and no reviewer can see it in a diff. The next obvious fix is a ruleset per team, and then you lose the ability to say whose rules run first, because you do not get to interleave two rulesets on the same phase from a pull request.

### Run it

- DO: run the GitHub Actions workflow, Actions -> topic-10-waf-composition
- DO: in Git Bash, run `bash scripts/demo-10-fragment-lint.sh`

### What just happened

> Against the three real fragments, rules/incident.yaml, security.yaml and app-team.yaml, the run reports 12 tests, 12 passed. Then the deliberately bad fixture goes through the same linter and produces exactly two FAIL lines, one for a skip action and one for an /admin path match. Two, not three or four, and that number is the interesting part.

> policy/waf_fragments.rego denies skip actions and /admin matches, but only for the app fragment. The security team's /admin rule is legitimate and it passes untouched. The policy is scoped to the fragment it applies to, so the same word means different things depending on who wrote it.

> Ordering lives in one place. waf-composed/main.tf contains `ordered_rules = concat(incident, security, app)`, and that single line is the only ordering authority in the repo. Everything compiles into one cloudflare_ruleset on phase http_request_firewall_custom, so there is no cross-ruleset ambiguity to argue about. Owner and review date are interpolated into every rule description by a comprehension, which means a rule cannot exist without attribution. CODEOWNERS routes each fragment path separately.

> Say this part out loud: on this single-member repo, all three CODEOWNERS handles resolve to me, because GitHub requires a code owner to have write access. The routing mechanism is real and the file is correct. Three separate teams are not actually being notified in this demo.

### The point

> Put ordering in exactly one line of code that a reviewer can read, and let ownership be a property of a file path rather than something people remember. Once composition order is a single expression and every rule carries its owner and review date automatically, a pull request stops being a trust exercise.

> Scope your policy checks to the fragment, not the ruleset. A blanket ban on /admin would have blocked the security team from doing their job, and a rule that blocks the people it is meant to protect gets switched off within a month.

### If asked

- **Why not one ruleset per team?** You cannot control evaluation order across rulesets on the same phase from a pull request. One ruleset with a concat is the thing you can review.
- **Does the linter actually block a merge?** It runs in the workflow and fails on the bad fixture with those two FAIL lines. Wire it as a required check and it blocks.
- **What if the app team genuinely needs an /admin rule?** They do not get it silently. The deny is scoped to their fragment, so the rule has to move to the security fragment, which changes who reviews it.
- **Are three teams really being reviewed here?** No. All three CODEOWNERS handles are me on this repo, because a code owner needs write access. In a real org those are three team handles and the routing works as written.

---

# TOPIC 11 - Kill-switch patterns: rules that live disabled in code and arm during incidents

### Why this matters

> It is the middle of the night and something is hammering one endpoint. Someone opens the Cloudflare console and adds a block rule by hand, because that is fast and a pull request is not. The incident ends. The rule stays. Weeks later nobody remembers who added it or what it was for, and nobody wants to be the person who deletes it.
>
> So you decide to do it properly next time, through Terraform, like everything else. Now you are authoring a brand new rule during the incident, with expression syntax you have not tested, asking a reviewer who was asleep to read the diff and tell you it is safe. That review is theatre. Nobody catches an inverted match at that hour, and if the plan comes back wrong you are debugging syntax while the attack is still running.
>
> Both paths fail for the same reason. You are writing the emergency logic during the emergency. The problem is not which tool you reach for, it is when the thinking happens.

### Run it

**DO:** Actions -> topic-11-kill-switch. The run arms and then disarms itself, timing both directions.

**DO:** In Git Bash, run `bash scripts/demo-11-arm.sh`.

**DO:** Call the timings out as they land. Locally, 6 seconds to arm and 7 to disarm. Via Actions, 4 seconds to arm and 3 to disarm.

### What just happened

> The whole change is one variable. `incident_mode` accepts none, elevated or lockdown and nothing else. There is a validation block, and there is deliberately no custom escape hatch. That refusal is the design, because an escape hatch would let someone pass a mode nobody ever reviewed.
>
> The rules live in `incident.yaml`, and each one carries a `min_mode`. Locals turn the three modes into a numeric rank, and every rule's enabled flag is bound to a comparison against that rank. So the plan you just watched could only do one thing: flip enabled flags. It cannot create a resource, and it cannot rewrite an expression. The shape of an incident diff is settled before the incident starts.
>
> Look at the times again. Six seconds to arm locally and seven to disarm, four and three through Actions. Disarming is no harder than arming, and that matters more than the speed does, because the switch you dread turning off is the one that quietly stays on.
>
> Then the backstop. `.github/workflows/killswitch-reminder.yml` runs hourly and queries the live Cloudflare API rather than the repo. It asks one question, is any `lab_ir_` rule enabled, and it exits 1 with an error annotation while any of them is. It has been passing on schedule, so a red run means something is genuinely armed right now.

### The point

> Pre-write the emergency and review it while nothing is on fire. Leave it in the codebase disabled, so the only thing that moves under pressure is a mode flag, and the only diff anyone reads during an incident is a column of true and false. That is why `.github/PULL_REQUEST_TEMPLATE/break-glass.md` asks reviewers to check boxes rather than read diffs. Their job at that hour is to confirm the decision, not to audit the logic.
>
> Then build the thing that turns it back off. An armed kill switch nobody disarms becomes permanent config nobody understands. Make "still armed" a failing check against live state rather than against your repo, so the clock starts the moment you flip it.

### If asked

- **"Could someone sneak a brand new rule in through incident_mode?"** No. The variable takes three values, the validation block rejects anything else, and every enabled flag is bound to the rank comparison. There is no path from that input to a new resource.
- **"Does scripts/arm-killswitch.sh apply the change?"** No. It is plan only, it contains no apply. Applying is a separate, deliberate step.
- **"Won't an hourly failing workflow just become noise?"** It only fails while a `lab_ir_` rule is actually enabled, and it has been passing on schedule. A failure is a signal, not background hum.
- **"Why query the Cloudflare API instead of the repo?"** The repo tells you what you intended. The API tells you what is live, so a `lab_ir_` rule someone armed by hand shows up too. Be honest about the limit though: the check only asks about `lab_ir_` rules, so a console rule added under some other name is outside what it can see.

---

# TOPIC 14 - Tunnel design: config source governance, ingress ordering, HA replicas, secret rotation

### Why this matters

> Picture the box that has been running your tunnel for a year. Somebody needed a new hostname in a hurry, so they SSHed in, edited `config.yml`, restarted cloudflared, and it worked. Six months later that box dies. You rebuild it from Terraform and half the routes are gone, because the file on that disk was the only copy of what the tunnel actually served, and the person who edited it has left.

> The obvious fix is to check `config.yml` into git and ship it with the machine. That holds up until the day you want a second connector so the first one can be patched without an outage. Now you have two files that have to agree, two restarts to sequence, and a drift problem that only announces itself when the one serving traffic is the one that is wrong.

> The same shape shows up when the credential ages out. You go to change the tunnel secret, expecting a config edit, and what you get back from plan is something much larger than you asked for.

### Run it

DO: Actions -> topic-14-tunnel-design-walkthrough

DO: Git Bash: `bash scripts/ci-demo-14-walkthrough.sh`

DO: Say out loud, before the output appears, that this topic cannot be run live. The lab API token can read tunnels but not create them, and the HA demo needs two cloudflared containers on a machine you control. The walkthrough prints the design and the real module source, and verifies its claims against the file rather than asserting them.

### What just happened

> Start with `config_src`. Set to `cloudflare`, the ingress rules live in Cloudflare under Terraform control instead of in a file on a box that anyone with SSH can edit. That single setting is doing more work than it looks like. It makes the connector stateless, and a stateless connector is what makes HA trivial. Run the same token twice, kill either one, nothing happens. No leader election, no shared storage, no pets.

> Look at the end of the ingress list. The last rule is service only and returns 404. First match wins, so ordering is the whole semantics of that list, and cloudflared will refuse a config whose last rule carries a hostname. The catch-all is not decoration, it is the thing that makes the config loadable.

> Then the rotation section, which is where the design earns itself. The naive approach changes the tunnel secret in place, and Terraform responds by destroying and recreating the tunnel. The DNS record points at the tunnel ID, so that is a real outage from apply-start until a new connector registers. The two-step version stands up a second tunnel, starts its connectors, repoints the DNS record in place, which is atomic at the edge, then drains the old one.

> Notice what that requires. The record has to survive the tunnel, so it cannot be owned by the module. `infra/envs/lab` owns the record and the module takes `manage_dns` false.

### The point

> Where a config lives decides what your operations look like later. Move the config out of the runtime and the connector becomes disposable, and everything you would otherwise build for HA stops being necessary.

> And the ownership question from Topic 9 is not academic. It shows up inside a runbook, as the difference between a zero-downtime rotation and a real outage. Whatever must outlive a resource has to be owned above that resource.

### If asked

- **Can we see the failover live?** Not here. The lab token reads tunnels but cannot create them, and you need two cloudflared containers on a machine you control. Today we are reading the module source that implements it.
- **Why can the last ingress rule not have a hostname?** First match wins down the list, so the final entry is the fallback. cloudflared refuses to load a config whose last rule is hostname-scoped. Ours is service only and returns 404.
- **Why not just change the secret in place?** Terraform destroys and recreates the tunnel. The DNS record points at the tunnel ID, so you are down from apply-start until a new connector registers.
- **Why does the environment own the DNS record?** Because the two-step rotation repoints that record from an old tunnel to a new one. If the module owned it, the record would be destroyed along with the tunnel it was supposed to survive.

---

# TOPIC 20 - GitHub environments as the human gate: reviewers, wait timers, scoped secrets

### Why this matters

> Look at the arrangement you land on by default. A write-scoped Cloudflare token sitting in repo secrets, because the apply job needs it. Now someone opens a pull request that edits the workflow file and adds one step. That step runs with your write token in it. Nothing malicious has to happen for this to be a bad arrangement. The credential is in the room before any human has read the change.

> The obvious fix is to require an approving review on the pull request. It does not help here. Branch protection gates the merge, it does not gate the job, and a job is handed its secrets the moment it starts running.

> The second problem is quieter. Approval arrives some time later, and in that gap somebody merged, or somebody clicked something in the Cloudflare dashboard. The reviewer read one set of changes. A different set is about to execute.

### Run it

DO: Open a pull request. Watch tf-pr run unit tests, then fragment lint, then plan with the READ-ONLY token in the lab-plan environment.

DO: Point at the saved plan artifact, named tfplan- followed by the commit SHA, at the OPA destroy guard running on the plan JSON, and at the summary comment posted on the PR.

DO: Trigger the apply: `gh workflow run tf-apply.yml -f plan_run_id=<id> -f sha=<sha>`

DO: Show the job sitting at Waiting.

DO: Open Settings, Environments, lab-apply. Show the required reviewer and the 1-minute wait timer.

DO: Click Review deployments, tick lab-apply, then Approve and deploy.

DO: Show it downloading that exact artifact and applying it. Say out loud that it does not re-plan.

DO: Part two. Open Actions, then topic-20-stale-plan-invariant. Or run `bash scripts/demo-20-stale-plan.sh`

DO: Read the failure out loud: `Error: Saved plan is stale ... the state was changed by another operation after the plan was created.`

### What just happened

> Two environments doing two different jobs. lab-plan holds only the read-only token, so everything that runs on a pull request is incapable of changing anything. That answers the hostile pull request. Rewrite the workflow to apply instead of plan and it still runs in lab-plan, and that credential gets a 403 back from Cloudflare. The blast radius of an untrusted contributor is a failed API call.

> lab-apply holds the write token and the protection rules together, and that pairing is the whole trick. GitHub injects environment secrets only after the protection rules pass. While the job sat at Waiting it had no credential at all. Approve and deploy is not a gate the job walks through, it is the moment the job is handed its token.

> Then watch what the apply consumed. It downloaded tfplan- plus the commit SHA, the same artifact the destroy guard inspected and the same one the summary comment described. It applied that file. It did not re-plan, so what the reviewer read is what ran.

> Part two is the safety net. A plan file is a serialized set of actions bound to the state serial it was computed from, so once the state moves, Terraform refuses the file rather than reinterpreting it. That is the stale plan error on screen.

### The point

> Put the credential behind the gate, not in front of it. In any CI system, ask one question of every secret: at what instant does the job receive it? If the answer is "when the job starts", your human review is decoration. If the answer is "when a named human approves", the approval is the security control.

> And approve an artifact, not an intention. Ship the reviewed plan file itself into the apply step, and let the tool refuse it when the world has moved underneath it.

### If asked

- **"Can't someone edit the workflow in a PR and just apply?"** They can try. It runs in lab-plan, which holds only the read-only token, so Cloudflare returns 403. Nothing is written.

- **"Does this work on my private repo?"** Not on the free tier. Environment protection rules are a public-repo feature there. Public repo, or a paid plan.

- **"Why not re-plan at apply time, it's simpler?"** Then the thing approved and the thing applied are two different computations. We apply tfplan-<sha> exactly. If state moved, we get the stale plan error instead of a silent difference.

- **"What is the 1-minute wait timer buying me?"** It is short here so the demo moves. In production it is the window to notice and cancel after somebody approves. It costs a minute and buys a change of mind.

---

# TOPIC 24 - terraform test tier one: provider mocking and sub-second logic tests

### Why this matters

> Picture the pull request everybody dreads. Someone changes the DNS module, adds an override, adjusts a default TTL, and the review comes down to two people reading HCL and guessing. The only way anyone can actually confirm the logic is to merge it and watch what lands in the zone. So the reviewer either trusts the diff or asks for a manual apply in a scratch account, and the pull request sits there for a day.
>
> The obvious next move is to make CI run a plan on every pull request, and this repo does exactly that: `tf-pr.yml` plans with the read-only token held in the gated `lab-plan` environment. But a plan is not a logic test, and it falls short for three separate reasons. A plan needs a Cloudflare token, so it can only run where a credential can safely be handed to the job, which rules out forks and puts an environment gate in front of the check. A plan talks to the API, so it is slow, it is rate limited, and it goes red when Cloudflare has a bad afternoon rather than when your code is wrong. And a plan answers the question "what would change", not the question you actually care about, which is "did my override beat the baseline, and does my validation rule still fire".
>
> So the gap is a test that runs on every pull request, in seconds, with no credential at all, and that still makes real assertions about your logic.

### Run it

> Actions -> topic-24-terraform-test
>
> Git Bash: `bash scripts/demo-24-unit-tests.sh`

### What just happened

> Five passed, zero failed, in about 0.4 seconds. Look at what the script printed before the suite ran. It listed the names of the credentials present in the shell, never the values, and then it removed every one of them and ran the tests anyway. That is not a claim in a README. You watched the credentials get stripped and the suite pass regardless.
>
> The mechanism is `mock_provider` in `tests/unit.tftest.hcl`. It swaps the Cloudflare provider for a stub that fabricates anything the API would have computed. Everything that comes from your variables and your locals stays completely real. Terraform still evaluates your expressions, your merges, your conditionals. It just never calls the Cloudflare API.
>
> The five run blocks are the interesting part. `settings_composition` proves an allow-listed override beats the baseline. `default_propagation` proves that omitting TTL really yields automatic. `invalid_record_type_rejected` uses `expect_failures`, so it passes only when a validation rule actually fires, which means your guardrails are tested rather than assumed. Then `fragment_ordering`, and `killswitch_arming`, which checks that elevated arms the elevated rule and does not arm the lockdown rule. That last one is a negative assertion, and negative assertions are exactly what nobody writes by hand.

### The point

> Split your tests by what they need to run, not by what they cover. Anything derived from variables and locals needs no API, so it belongs in a tier that runs on every pull request with no credential. Anything that needs the real service belongs in a second tier. Tier one here is wired into `tf-pr.yml`. Tier two lives in `tests/contract`, applies against the real zone with `tftest-` prefixed resources that `terraform test` auto-destroys, and runs nightly and on demand, never on pull requests.
>
> One honest wrinkle on that nightly run: the write token tier two needs lives only in the gated `lab-apply` environment, so a scheduled run queues for human approval rather than firing unattended. More on that below.
>
> The payoff is that the fast tier is cheap enough to run constantly, so people actually run it, and the expensive tier stays small enough to trust.

### If asked

- **Does mocking mean the tests are fake?** No, but be precise about what they prove. They prove your composition and validation logic. They do not prove Cloudflare accepts the payload. That is what tier two is for, and that is why tier two exists.
- **Why not run tier two on pull requests too?** It applies real resources to the real zone. That needs a write token, and a write token on a pull request branch is a credential you have handed to anyone who can open a pull request.
- **Does the nightly tier-two run actually run unattended?** No, and this is worth saying honestly. The write token only lives in the gated lab-apply environment, so a scheduled run queues for human approval instead of running on its own. That is a genuine conflict between unattended write automation and a human gate on writes.
- **So how do you resolve that?** You give CI its own narrowly scoped credential. You do not resolve it by removing the gate.

---

# TOPIC 27 - Drift detection: nightly baseline, author attribution, and structural prevention

### Why this matters

> Picture a Friday evening. A record is misbehaving, someone with dashboard access drops the TTL on lab-hello to 900, the pages load again, everyone goes home. The change was correct in the moment and nobody wrote it down anywhere. Three weeks later a colleague runs an apply for an unrelated reason and silently reverts it, or sees a diff they do not recognise and cancels the deploy on the spot.

> The obvious fix is a rule. Tell people not to click in the console, put it in the runbook, repeat it at onboarding. That rule survives until the next incident, because during an incident the console is the fastest tool in the room and the person reaching for it is doing the right thing. The second obvious fix is to read the plan before every apply, but that only catches drift at the moment somebody happens to run Terraform, which may be a month later.

> The gap is not knowledge and it is not discipline. Nothing is looking, on a schedule, at whether the live account still matches the code.

### Run it

**DO:** Actions -> topic-27-drift-detection

**DO:** Git Bash: `bash scripts/demo-27-make-drift.sh`

**DO:** Actions -> drift, the scheduled nightly detector, which is also dispatchable

### What just happened

> The demo made a change out of band and told you so in one line, `drifted: ttl -> 900`. Then it did the only thing a drift detector actually does. It ran `terraform plan -detailed-exitcode` and looked at the number that came back. Zero means clean, one means the plan errored, two means the live world and the code disagree. You saw `exit code 2 - drift detected, exactly as the nightly workflow would see it`. That is the whole detector. A scheduled job and an exit code.

> The report then named the offender rather than dumping a wall of plan output: `1 resource(s) drifted from code truth`, pointing at `module.zone_baseline.cloudflare_dns_record.this` for lab/lab-hello, with actions `update`. This lab has no remote state, so the nightly job imports the live objects into an ephemeral state and compares them against the committed code. Anything the plan proposes beyond the import itself is drift. That is arguably the better question anyway. Not live versus your last apply, but live versus what is in git.

> One line is an honest failure. `Audit lookup unavailable (HTTP Error 403)`. The script renders the plan to JSON and tries to correlate the drifted resource IDs against the Cloudflare audit log to name the human who made the change. No token on this account can read audit logs, so it says so cleanly and moves on. Detection works. Attribution has never once returned a real actor here.

> The run finished with `drift healed.`, and the nightly workflow you dispatched afterwards reported `drifted resources: 0` and `No drift - live matches the committed code.`

### The point

> You do not need a drift product. You need a cron job, one Terraform flag, and somewhere for the exit code to go. Everything else is presentation.

> Detection is the backstop, not the fix. The structural fix is documented in this repo and deliberately not applied: move human dashboard roles to Administrator Read Only, so people keep full visibility and lose the pencil, and let the pipeline's scoped token be the only credential on the account that can write. Then drift stops being something you detect and starts being something that cannot happen.

### If asked

- **Why did the attribution fail?** No token on this account can read audit logs, so the API returns 403. The correlation logic is real, the naming is unverified. Do not sell it as working.
- **Why not just apply the read-only role change now?** The sandbox login is the only access the presenter has. Locking it to read-only would end this session.
- **Do I have to wait for the cron?** No. `drift.yml` runs on a nightly cron and on workflow_dispatch, with a per-environment matrix, so you can trigger it on demand exactly as you just did.
- **What if I do have remote state?** Then you drop the import step and plan directly. The exit code contract is identical.

---

# TOPIC 29 - Brownfield adoption: cf-terraforming, for_each import blocks, generation, normalization

### Why this matters

> You inherit a zone that nobody built with Terraform. The records were made by hand in the dashboard, or by a script somebody wrote against the API two years ago and then left the company. In this lab it is five lab-legacy TXT records with TTLs of 120, 240, 360, 480 and 600, plus a rate-limit ruleset. Your real estate has the same shape with two more zeros on the end.

> Now someone asks you to bring it under Terraform. The obvious move is to hand-write the HCL and import one resource at a time. That falls over twice. You need a resource address and an import for every object, which stops being realistic past a few dozen. And you have to guess the configuration exactly right before you apply, because on apply Terraform makes the API match whatever you wrote. Every field you got slightly wrong is a live change to production.

### Run it

- DO: Actions -> topic-29-brownfield-adoption (the workflow seeds first)
- DO: Git Bash: `bash brownfield/seed-legacy.sh` then `bash scripts/demo-29-adopt.sh`

### What just happened

> Three techniques, because there are three situations. Discovery first: cf-terraforming reads the live zone and emits real HCL for 6 live records. That tells you what is actually out there.

> Then the bulk path. The five TXT records do not get five hand-written import blocks. They get one import block with for_each over a CSV, and the plan reads "Plan: 5 to import, 0 to add, 0 to change, 0 to destroy." Read the zeros as carefully as the five. Terraform is only taking ownership of what already exists.

> The ruleset is the gnarly one, deeply nested and miserable to type, so Terraform writes it with terraform plan -generate-config-out. What comes out is verbose, full of null optionals and echoed computed attributes, so normalize.py strips it and the log says "normalized generated_ruleset.tf: removed 84 noise lines". Then "Apply complete! Resources: 6 imported, 0 added, 0 changed, 0 destroyed." and one more plan gives "No changes. Your infrastructure matches the configuration."

### The point

> Adoption is not finished when the apply succeeds. It is finished when the next plan comes back empty. That is why this run fails loudly and exits 1 if the final plan is not empty. Put that gate in your pipeline, not in your head.

> The first run of this reported 5 changed. Adoption was about to silently rewrite five live records. The cause was an em-dash in the seeded TXT content. Cloudflare stores non-ASCII in TXT records as octal escapes, so the config said one thing and the API held another, and Terraform was about to fix the API to match the config. On five lab records that is nothing. On five hundred production records whose differences are TTLs and comments accumulated over years, that is an afternoon of unexplained changes and a very bad incident review.

### If asked

- **"The plan said 5 to import, the apply says 6 imported. Why?"** That plan was the CSV import block on its own, the five TXT records. The ruleset arrives on the other path, its own import block with the configuration Terraform generated. Five plus one is the six the apply reports. Do not reach for cf-terraforming's six to explain it: that is a separate discovery count of live records and the ruleset is not in it.
- **"Can I just use cf-terraforming for the whole migration?"** Use it for what it is good at here, discovery. Repetitive records go through the one import block with for_each, and the nested ruleset goes through generate-config-out, where Terraform writes the configuration itself.
- **"Why bother normalizing the generated config?"** One ruleset carried 84 lines of noise, all null optionals and echoed computed attributes. Across a real estate that makes the pull request unreviewable.
- **"What do I do when the final plan is not empty?"** Nothing, until you understand every line of it. The gate is the last step, after the imports have been applied, and it exits 1 there so the run fails and nobody refactors on top of a config that disagrees with reality. Ours turned out to be octal escapes for one non-ASCII character.

---

# TOPIC 32 - Sharp edges: phase ownership, dual writers, list scale, plan noise

### Why this matters

> Picture the Monday plan on your DNS repo. Nobody changed anything, and Terraform says one record will change. You open the diff and it reads example.com becoming example.com. Look harder and the difference is a trailing dot. You wrote that dot because every DNS textbook tells you to write it, and Cloudflare stores the target without it. Apply it, and the next plan says the same thing again. Keep that up and people stop reading plans on that repo at all, they just look for the number and move on.

> The obvious fix is ignore_changes on that attribute, and it is the worst thing you can do here. It does not silence a false diff. It stops Terraform managing that attribute at all. So the day somebody repoints that CNAME at a hostname you have never heard of, the plan stays quiet about that too. You traded a cosmetic annoyance for blindness on the single most important field on the record.

> Noise is only the first altitude. The same shape shows up when a second team imports a record your pipeline already created, and again when two repos reach for the same ruleset phase, and again when you decide how to express five hundred IPs.

### Run it

DO: Actions, run `topic-32-plan-noise`, then `bash scripts/demo-32-noise.sh`
DO: Actions, run `topic-32-dual-writers`, then `bash scripts/demo-32-dual.sh`
DO: Actions, run `topic-32-phase-ownership`, then `bash scripts/demo-32-phase.sh`
DO: Do NOT run sub-demo D live. It is too slow and it fails on purpose. Walk the room through the recorded measurements instead — they are real numbers from an actual run.

### What just happened

> In the first run the log says "applied. API actually stored: example.com", then shows a content diff from example.com to example.com with a trailing dot, then "Plan: 0 to add, 1 to change, 0 to destroy." after apply one and again after apply two. Two applies, same diff, no progress. Once the canonical form is written the script reports "plan is QUIET". Be honest with the room here. This demo was originally built around letter case, which used to be a classic Cloudflare gotcha. Provider version 5 normalizes case now, so that version of the bug does not reproduce at all, and the same is true of TXT quote wrapping. We found that by running it, not by reading about it.

> The dual writers run is the quiet one. Live content goes owned-by-A, then owned-by-B, then owned-by-A, and nobody errors, ever. Both pipelines stay green the whole time. All root B did was import a record root A created, which looks like ordinary onboarding. Your detection hook is the audit log: the actor there is the other team's pipeline token. Drift attributed to a service credential rather than a human almost always means two writers, not a rogue admin.

> Phase ownership is the loud one, and loud is the best of the four outcomes. "A owns the phase. A's pipeline is green." then B's apply fails. We use http_request_firewall_managed so we never touch the real WAF phase. The failure is not the problem, the human response is. B unblocks itself by deleting A's ruleset in the dashboard, A's next apply recreates it, and B breaks again.

> For list scale, same five hundred IPs two ways. As one list with an items collection: apply 51 seconds, no-op plan 31 seconds. As five hundred individual list-item resources: no-op plan 43 seconds, and the apply did not complete. Cloudflare rate-limited the individual POSTs, Terraform aborted partway and left 496 of 500 entries, matching neither the code nor the previous state. Deleting the whole list with one API call took 2 seconds. The headline is not slower, it is does not work.

### The point

> All four are the same disease at different altitudes. A shared thing with two owners, or an ownership decision somebody made without noticing they were making it. Trailing dot, imported record, ruleset phase, list granularity, all ownership.

> The API referees loudly sometimes and not at all other times, and the quiet cases are the expensive ones. So spend your review effort where nothing errors. A green plan is not evidence of agreement, it is only evidence that nobody collided this hour.

### If asked

- **Is ignore_changes ever right?** For a field you genuinely do not manage, yes. Never for the target of a record. Fix the input to match the canonical stored form instead.
- **Why not just let both teams write the record?** They already can, and that is the demo. Nobody errors. Pick one writer and give the other read access or a separate record.
- **Should we ever use per-item list resources?** Only if you truly need per-item ownership, and understand that at this scale it did not work at all. Our 500-item apply never completed — Cloudflare rate-limited the POSTs and Terraform left 496 of 500 entries behind. It also charges you on every plan forever.
- **How would we have caught the dual writer in production?** Audit log actor. If drift is attributed to a pipeline token rather than a person, look for a second pipeline before you look for a rogue admin.

---

# CLOSING

> "Several of the things I showed you were failures on purpose, and they were
> the same failure wearing different clothes: a shared thing with two owners.
> A zone setting. A DNS record. A ruleset phase. A list of five hundred entries
> that somebody modelled as five hundred owners without deciding to."
>
> "The API tells you about some of these immediately and never tells you about
> others. The loud ones cost you an afternoon. The quiet ones run for months
> and surface during an incident, when you discover your config stopped
> describing production some time in the spring."
>
> "So: decide ownership deliberately. Make the rule executable rather than
> written down, because a policy that is not a check is a hope. And put the
> human approval where the credential is, not where the merge button is."

---

# RESET, before delivering again

```bash
source ~/.cf-lab-env && cd "D:/Work/Claude/Shared Subnet Diagram/cf-terraform-lab"
terraform -chdir=infra/envs/lab apply -auto-approve -input=false >/dev/null
echo "reset done"
terraform -chdir=infra/envs/lab plan -input=false | grep -E "No changes|^Plan:"
```

Every demo resets itself as its last act. Topic 27 heals the drift it made,
Topic 29 clears its own state so it re-imports, and the Topic 32 demos destroy
what they create. The only thing that can be left behind is Topic 27's TTL
change if you interrupt it mid-run, and the apply above fixes that.

# WHAT IS NOT LIVE, and what to say

Three honest limits. Saying them plainly lands better than being caught.

| Limit | What to say |
|---|---|
| **Topic 14 does not run.** The lab token can read tunnels but not create them, and the HA demo needs two containers on a machine I control. | "I am walking through this one rather than running it. I would rather show you the design and the real module than fake a run." |
| **Topic 27's attribution returns 403.** No token on this account can read audit logs. Detection works fully; the naming does not. | "The detector works and you can see it. The audit join needs one more permission on this token, and the script says so in one line rather than pretending." |
| **Topic 32's list-scale is numbers only.** It needs account-level list permissions this token lacks, and at 500 items it fails on purpose. | "I measured this rather than running it live, because it takes too long and it fails deliberately. Here are the real numbers." |

Also: the three CODEOWNERS entries all resolve to one account, because GitHub
requires a code owner to have write access and this repo has one member. The
routing mechanism is real; three separate teams are not being notified.

# TROUBLESHOOTING

| Symptom | Cause and fix |
|---|---|
| `The term 'source' is not recognized` | You are in PowerShell. Switch to Git Bash. Nothing is broken |
| `command not found: terraform` or `jq` | Same cause, or a Git Bash opened before the tools were installed. Open a fresh one |
| `unbound variable` or 401s | You skipped the setup line. Run `source ~/.cf-lab-env` in this terminal |
| `No such file or directory: scripts/...` | Wrong directory. The setup line cds for you |
| Pre-flight shows `Plan: 0 to add, 1 to change` | A previous run was interrupted. Run the RESET block |
| A workflow sits at "Waiting" | That is the gate working. Review deployments, tick lab-apply, Approve and deploy |
| Topic 29 says `resource already managed` | Stale adopt state. The script clears it automatically now |
