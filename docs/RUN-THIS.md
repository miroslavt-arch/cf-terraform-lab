# RUN THIS — the demo, with the talk track

Two windows: **Chrome** (5 tabs, in order) and **one terminal**.

- **DO** = a click or a paste.
- **SAY** = narration. Written to be spoken, not read aloud verbatim — use it
  as the argument you are making, in your own words.
- **IF ASKED** = the questions that actually come up.

**Tabs, left to right:**

| Tab | What |
|---|---|
| **1** | Pull request #1 |
| **2** | Actions |
| **3** | Settings → Environments |
| **4** | Cloudflare DNS records |
| **5** | Code: `waf-composed/main.tf` |

**Terminal, before you share your screen:**
```bash
source ~/.cf-lab-env && cd "D:/Work/Claude/Shared Subnet Diagram/cf-terraform-lab" && clear
```

## TIMING

| Time | Topic | Where |
|---|---|---|
| 0:00 | Opening | Tab 5 |
| 0:05 | **20** — GitHub environments as the human gate | Tabs 1→3→2→4 |
| 0:25 | **24** — terraform test tier one | Terminal |
| 0:33 | **7** — module design | Terminal |
| 0:43 | **10** — WAF ruleset composition | Terminal + Tab 5 |
| 0:53 | **9** — settings baseline, singleton ownership | Terminal |
| 1:01 | **11** — kill-switch patterns | Terminal + Tab 2 |
| 1:11 | **29** — brownfield adoption | Terminal |
| 1:21 | **32** — sharp edges | Terminal |
| 1:34 | **27** — drift detection | Terminal |
| 1:43 | **14** — tunnel design | Tab 5 |
| 1:52 | Close | — |

Running short? Cut Topic 14, then one Topic 32 demo, then the Topic 7 tag
diff. Never cut Topic 20 or 29 — those two change minds.

---

# 0:00 — OPENING (5 min)

**Tab 5.**

**SAY**

> "Everything you are about to see is real. A real Cloudflare zone, real
> Terraform state, real GitHub Actions runs. Nothing is a mock-up and nothing
> is pre-recorded. If something fails while I'm doing it, that's a genuine
> failure and we'll look at it together."
>
> "There are ten topics. Four of them are deliberate failures — I am going to
> break things on purpose, because in infrastructure code the failure modes
> are the actual curriculum. Anyone can show you a working `terraform apply`.
> The useful knowledge is what happens when two teams both think they own the
> same resource, or when the API quietly rewrites what you asked for."
>
> "One word on safety, since we're pointing at a live account. Every resource
> this lab creates is named `lab-` something, or lives under a `lab.`
> subdomain. There's an Open Policy Agent rule wired into the pipeline that
> fails any plan proposing to destroy a resource without that marker. So the
> blast radius isn't a promise I'm making you — it's a check that runs. That's
> a pattern worth stealing on its own: if your safety rule isn't executable,
> it isn't a safety rule, it's a hope."

---

# 0:05 — TOPIC 20 — GITHUB ENVIRONMENTS AS THE HUMAN GATE (20 min)

*Do this first: it has a timer in it, and it frames everything else.*

## The problem, before touching anything

**SAY**

> "Here's a failure I want you to hold in your head. A reviewer looks at a
> Terraform plan in a pull request. It says: modify one DNS record. They
> approve. Twenty minutes later the pipeline runs `terraform apply` — and
> `apply` computes a *fresh* plan against the world as it is now. In those
> twenty minutes someone merged, or clicked something in the dashboard. The
> plan that executes is not the plan that was approved."
>
> "Nobody did anything wrong. Every step passed review. And the thing that
> reached production was never seen by a human. That's the gap this topic
> closes, with two mechanisms: a plan pinned as an artifact, and a credential
> the pipeline cannot reach until a person says so."

## Step 1 — the plan CI wrote → **Tab 1**

**DO**
- Scroll to the comment **"Terraform plan for 2277b17d"**
- Click the triangle **plan output** to expand it

**SAY**

> "I didn't run this plan. When I opened this pull request, a GitHub Action
> ran `terraform plan` and posted the output back as a comment. That matters
> for a boring reason: the reviewer doesn't need Terraform installed, doesn't
> need credentials, and doesn't need to trust my screenshot. The plan comes
> from the same automation that will do the applying."

**DO** — point at **Artifact: tfplan-2277b17d…**

> "Now the important part. The plan wasn't just printed — it was saved as a
> binary artifact, named after the commit SHA. A Terraform plan file isn't a
> text report. It's a serialized set of exact actions bound to the exact state
> snapshot it was computed from. Remember that. In ninety seconds I'll show
> you what happens when reality moves out from under one."

## Step 2 — the planning job cannot write → **Tab 3**

**DO** — click **lab-plan**, point at **Environment secrets**

**SAY**

> "The plan job runs in this environment. One secret:
> `CLOUDFLARE_API_TOKEN_PLAN`, scoped read-only across DNS, zone settings and
> the WAF."
>
> "The framing I'd push back on is 'we trust the plan job'. Trust isn't the
> mechanism. The plan job is *incapable* of writing — if someone slipped a
> malicious `terraform apply` into a pull request from a fork, it would run
> with a credential that gets a 403 from Cloudflare. That's the difference
> between a policy and a property. Policies are things people follow.
> Properties are things the system cannot violate."

## Step 3 — the gate itself → **Tab 3**

**DO** — breadcrumb **Environments** → click **lab-apply**
- Point at **Required reviewers** (your name), **Wait timer** (1 minute)
- Scroll, point at **Environment secrets**: `CLOUDFLARE_API_TOKEN`

**SAY**

> "This is where the write token lives, and look what's attached to it: a
> required reviewer and a wait timer, in the same box as the credential. In
> GitHub, environment secrets are only injected once the protection rules
> pass. So the approval isn't a gate the job walks through — it's the thing
> that hands the job its keys."
>
> "The wait timer is one minute here so you can see it. In production you'd
> tune it to your 'oh no, stop' window: long enough that someone who realises
> they've made a mistake can cancel, short enough that it isn't friction.
> Small idea, catches a real class of incident."
>
> "One caveat worth knowing: environment protection rules on the free tier are
> a **public repository** feature. If this repo were private, these controls
> wouldn't be here at all."

## Step 4 — fire it → **TERMINAL**

```bash
gh workflow run tf-apply.yml --repo miroslavt-arch/cf-terraform-lab -f plan_run_id=32469271562 -f sha=2277b17df45af3490cb772aa34838674d244793e
```

**SAY**

> "Two inputs — and notice what's *not* there. I'm not passing what to change.
> I'm passing which run produced the plan, and which commit it belonged to.
> The apply job's entire job description is: fetch that artifact, apply that
> artifact."

## Step 5 — watch it refuse to start → **Tab 2**

**DO** — F5, click the top **tf-apply** run, point at yellow **Waiting**

**SAY**

> "Nothing is running. No checkout, no Terraform, no token. The timer is
> counting, and after it there's an approval. If I walked out of this room
> right now, nothing would ever reach Cloudflare — it would sit here and
> eventually expire."

## Step 6 — fill the minute with the invariant → **TERMINAL**

```bash
bash scripts/demo-20-stale-plan.sh
```

**SAY while it runs**

> "While that counts down — this is the part I care most about. The script
> does three things. It saves a plan, exactly like the pipeline does. It
> simulates someone changing a record out of band, the way a dashboard click
> would. Then it tries to apply the plan it saved."

**DO** — when the red block appears, stop talking. Let them read. Point at
**Saved plan is stale**.

**SAY**

> "Terraform refused. Not a warning — a refusal. The plan file records the
> state serial it was computed against, and if the state has moved, applying
> it is no longer a defined operation, so Terraform won't do it."
>
> "This is the whole reason the artifact matters. Process can be skipped —
> people skip process at three in the morning during an incident. This can't
> be skipped, because it isn't process. It's the tool refusing to do something
> incoherent. Your reviewer approved a specific set of actions against a
> specific world; if that world changed, the approval is void and you go
> around again."

## Step 7 — approve → **Tab 2**

**DO** — **Review deployments** → tick **lab-apply** → **Approve and deploy**
- Click into the job, expand **download the EXACT plan artifact**, then
  **apply the pinned plan — NOT a fresh plan**

**SAY**

> "Watch the two steps. It downloads the artifact by name. Then it runs
> `terraform apply` with the plan file as an argument — no `-auto-approve`, no
> re-plan, because there's nothing left to decide. Every choice was made when
> the plan was computed and reviewed."

## Step 8 — the result → **Tab 4**

**DO** — F5, point at **lab-ci-demo**

**SAY**

> "A human approved a specific plan, and a machine applied exactly that plan.
> Between those two events, nothing was reinterpreted."
>
> "What this doesn't solve, so I'm not overselling it: it doesn't stop a bad
> plan from being approved. If the plan says 'destroy the production zone' and
> your reviewer clicks approve, this machinery will faithfully destroy the
> production zone. That's what the policy layer is for, and it shows up in the
> next few topics."

**IF ASKED**

- *"Why not just protect the branch?"* — Branch protection governs what gets
  merged. It says nothing about what a job does with credentials afterwards.
  They're complementary: branch protection guards the code, environments guard
  the credential.
- *"What if two PRs are open at once?"* — Both produce plans; whichever
  applies first invalidates the other's plan, and the second gets exactly the
  stale-plan refusal you just saw. The invariant handles the race for you.
- *"Where's the state?"* — Deliberately local here; see the honest note at the
  end of Topic 29.

---

# 0:25 — TOPIC 24 — TERRAFORM TEST TIER ONE (8 min)

## The problem

**SAY**

> "There's more logic in a mature Terraform codebase than people admit.
> Merging maps, computing `for_each` keys, deciding which rule is enabled at
> which incident level, deriving names. That's real logic with real bugs. The
> traditional way to find those bugs is to run a plan against a real account
> and read it carefully — which means every test needs credentials, network,
> and about forty seconds. So people don't test. They review harder and hope."
>
> "Terraform 1.7 added `mock_provider`. The provider gets replaced with a stub
> that fabricates plausible values for anything the API would have computed.
> Everything derived from your variables and locals stays real. So you test
> your logic — the part you actually wrote — with no credentials and no
> network."

**DO**
```bash
bash scripts/demo-24-unit-tests.sh
```

**SAY** — point at **real 0m0.3xxs**

> "Five tests. A third of a second. No token in the environment — the script
> prints that first so you can see it isn't cheating."
>
> "Look at what's asserted, because that's the useful part. One test checks
> that an allow-listed override actually beats the baseline. Another checks a
> default propagates to the resource — that if I omit TTL, I really do get
> automatic. One is an `expect_failures` case: it feeds deliberately invalid
> input and asserts the plan *fails*, which is how you test a validation rule
> instead of writing one and assuming. And one asserts the WAF rules come out
> in the intended order."
>
> "The speed isn't a vanity metric, it's the adoption strategy. At forty
> seconds and a credential, tests get run before releases, maybe. At a third
> of a second and nothing, they run on every push and nobody argues about it
> in a planning meeting."

**SAY** — the second tier

> "There's a second tier, and the split matters. Tier two applies against the
> real zone with resources prefixed `tftest-`, and `terraform test` destroys
> them automatically when the run ends. Those catch what mocks can't — that
> the API actually accepts your payload. But they're slow and need write
> credentials, so they run nightly and on demand, never in the pull-request
> path. Mocked tests tell you your logic is right; contract tests tell you
> your assumptions about the provider are right. You need both, at different
> frequencies."

**IF ASKED**

- *"Doesn't mocking hide real bugs?"* — Yes, deliberately. A mock cannot tell
  you Cloudflare rejects your field; that's tier two's job. What tier one
  gives you is confidence your merge logic is correct, cheaply enough to run
  always.

---

# 0:33 — TOPIC 7 — MODULE DESIGN (10 min)

## The problem

**SAY**

> "Most Terraform modules die the same death. They start with three variables.
> Someone needs an exception, so a fourth appears. Two years later there are
> forty, half of them `null` by default, nobody knows which combinations are
> legal, and no one dares delete any because something somewhere might set
> them. The module became a pile of switches."
>
> "The alternative is to treat the variable block as an API: small, typed,
> defaults visible in one place, and illegal states made loud."

**DO**
```bash
bash scripts/demo-07-validation.sh
```

**SAY** — point at the red **Invalid value for variable**

> "That message was written by the module author. It fired at plan time, in my
> terminal, before anything touched the network."
>
> "Compare with the alternative. Without the validation, this input sails
> through plan, starts an apply, creates two resources, then fails on the
> third with a Cloudflare API error — leaving a half-built estate and an error
> message written by someone who has no idea what your module is for.
> Validation moves the failure earlier and moves the explanation closer to the
> person who can act on it."
>
> "And notice what the message says. Not 'invalid input' — it says which rule
> was broken and why the rule exists. A good validation message is
> documentation that executes. It's the only documentation that can't drift,
> because it's the thing doing the checking."

**DO**
```bash
git diff v0.1.0 v0.2.0 -- infra/modules/zone-baseline/variables.tf
```

**SAY**

> "The other half of module design is versioning. The consumer pins a git tag,
> not a branch. Point at a branch and your infrastructure changes when someone
> else pushes — you've made every consumer's deploy depend on a repo they
> don't control."
>
> "This is the entire diff between two versions: one new input, `optional`,
> with a default. That's what makes it a minor version rather than a breaking
> one. Every existing caller moves to this tag and gets a zero-change plan —
> exactly the property you want to be able to promise, because it's what lets
> people upgrade without ceremony."
>
> "The outputs are the other half of that contract. Callers depend on their
> shape, so changing an output is a breaking change even though nothing in
> your infrastructure changed. If you take one thing from this topic: your
> module's variables and outputs are a public API, and everything you know
> about not breaking APIs applies."

---

# 0:43 — TOPIC 10 — WAF RULESET COMPOSITION (10 min)

## The problem

**SAY**

> "A Cloudflare zone has one entrypoint ruleset per phase. One. But in a real
> organisation three groups have a legitimate claim on the custom rules:
> incident response wants emergency controls, the security team owns standing
> protections, the application team wants rules specific to their app."
>
> "So there's a genuine conflict: one resource, three owners. The wrong
> answers are all common. Give everyone write access to one file and let git
> sort it out — merge conflicts, and rules that silently change order. Or make
> one team gatekeeper for every change — the security team becomes a ticket
> queue, and people route around them."

**DO**
```bash
bash scripts/demo-10-fragment-lint.sh
```

**SAY** — point at the two red **FAIL** lines

> "Each team owns a YAML fragment. The module composes them. And each fragment
> is linted *on its own*, so when the app team writes something they
> shouldn't, the failure lands on their pull request with a message aimed at
> them — rather than on a merged artifact where nobody knows who introduced
> it."
>
> "Look at what's blocked. First, a `skip` action. In Cloudflare's rules
> engine `skip` bypasses subsequent rules — so an app-team rule with `skip` can
> silently disable the security team's protections above it. It isn't
> malicious; someone's load-testing tool was getting challenged and this made
> the problem go away. Second, a rule matching an `/admin` path, which is the
> security team's territory."
>
> "The structural point: the policy lives in `policy/`, and CODEOWNERS routes
> that directory to the security team. So the app team can propose any rule
> they like, and they cannot edit the thing that says no to them. That
> separation is what makes it governance rather than a suggestion."

**DO** — **Tab 5**, point at `ordered_rules = concat(...)`

**SAY**

> "This one line is the org chart. Incident, then security, then app. Rules
> evaluate in order, so this is a real security property, not cosmetics — no
> team's edit can reorder another team's rules, because the ordering isn't
> data anyone edits. It's structure."
>
> "One more thing you can't see from here: the module interpolates the owning
> team and a review date into every rule's description as it builds them. So
> when you're staring at a rule in the Cloudflare dashboard at two in the
> morning, it tells you who owns it and when it was last reviewed. Attribution
> by construction — a rule literally cannot exist in this ruleset without it."

---

# 0:53 — TOPIC 9 — SETTINGS BASELINE AND SINGLETON OWNERSHIP (8 min)

## The problem

**SAY**

> "Zone settings are singletons. There is exactly one `security_level` for a
> zone. No create, no delete — only set. That sounds harmless, and it produces
> one of the nastiest failure modes in infrastructure as code."
>
> "If two Terraform roots both declare that setting, neither errors. Ever.
> Each sets the value to its own truth on every apply. Both teams have green
> pipelines. Both believe they're in control. And the value in production
> depends on which pipeline ran most recently."

**DO**
```bash
bash scripts/demo-09-singleton-flap.sh
```

**SAY** — point at the values as they print

> "Root A applies: high. Root B applies: essentially off. Root A's nightly
> run: back to high. Nobody errored. Nothing is broken from either pipeline's
> point of view."
>
> "Sit with how bad this is. If the setting were something that mattered — a
> TLS minimum version, say — you'd have a security control that's correct
> roughly half the time, flipping on a schedule, with two teams each able to
> demonstrate a green pipeline proving they configured it correctly. And no
> error anywhere to alert you."
>
> "The fix is ownership, in two halves. First: the baseline is a single
> `locals` map in one module. One root owns settings, full stop. Second — and
> this is the half people skip — that owner publishes a door. There's an
> `overrides` variable with a validation block that allow-lists exactly which
> settings a caller may override."
>
> "Why the door matters: if the only way to change a setting is a pull request
> against the central module, you've made the platform team a bottleneck, and
> people route around bottlenecks — usually by clicking in the dashboard,
> which is how you get drift. So you decide deliberately which settings are
> safe to delegate, and you make that list executable. Try to override
> anything else and the plan fails with a message explaining where that
> request belongs."

**IF ASKED**

- *"What if two teams genuinely need different values?"* — Then they need
  different zones. A singleton with two required values isn't a Terraform
  problem, it's a requirements conflict, and IaC just makes it visible.

---

# 1:01 — TOPIC 11 — KILL-SWITCH PATTERNS (10 min)

## The problem

**SAY**

> "Think about the worst conditions under which anyone writes a firewall rule.
> It's during an incident. It's late. The person writing it is stressed,
> possibly woken up, and definitely not getting a careful review — because the
> whole point is speed. So the code that runs under the highest stakes gets
> the least scrutiny of anything you ship."
>
> "The pattern that fixes this is almost embarrassingly simple. Write the
> emergency rules now, in daylight, with a proper review. Deploy them. Leave
> them disabled. Then arming during an incident is a *data* change, not a code
> change."

**DO**
```bash
bash scripts/demo-11-arm.sh
```

**SAY** — point at **ARMED at the edge in 6 seconds**

> "Six seconds from decision to live at the edge. And six seconds back — the
> reverse direction matters just as much, because a control you're afraid to
> turn off is a control you'll hesitate to turn on."
>
> "But the number isn't really the point. The point is what I *didn't* do. I
> didn't write a rule expression under pressure. I didn't get a rule reviewed
> at two in the morning by whoever was awake. I changed one word in a
> variables file, and the plan for that change can only ever flip `enabled`
> flags on rules whose logic was reviewed months ago. The diff a reviewer sees
> during an incident is one line — approvable in seconds, without reading
> firewall syntax."
>
> "That's why the repo has a break-glass pull request template. The reviewer
> isn't checking the rule, they're checking boxes: is the only change the
> incident mode, does the plan touch nothing else, is there an incident
> ticket. Pre-approving the *shape* of the change is what makes fast review
> safe."

**DO** — **Tab 2**, click **killswitch-reminder**, point at the green checks

**SAY**

> "The other half is getting back to normal. The dangerous state isn't the
> incident — it's three weeks later, when a lockdown rule is still challenging
> every visitor and nobody remembers arming it."
>
> "This workflow runs hourly. Note what it checks: it queries the Cloudflare
> API and asks whether any incident rule is currently enabled. It does not
> read the repo. It checks reality, because the failure you're guarding
> against is precisely reality and intent having diverged. While anything is
> armed it fails, and a failing scheduled workflow emails the repo owner. It
> makes forgetting expensive."

---

# 1:11 — TOPIC 29 — BROWNFIELD ADOPTION (10 min)

## The problem

**SAY**

> "Almost nobody starts greenfield. You inherit an estate built by dashboard
> clicks over five years, by people who've left, and you're asked to bring it
> under Terraform without an outage."
>
> "The definition of success is precise, and worth stating before we start:
> you reach a plan that says **No changes**, and you get there without
> modifying a single live resource. State-only operations. If adoption changes
> anything, adoption failed — you didn't adopt the estate, you overwrote it
> with your guess about the estate."

**DO**
```bash
bash scripts/demo-29-adopt.sh
```

**SAY while it runs**

> "There are six resources here Terraform has never seen — five DNS records
> and a rate-limit ruleset, created by raw API calls the way a dashboard user
> would, with inconsistent TTLs, because real estates are untidy."
>
> "Three techniques, for three situations. `cf-terraforming` is discovery —
> what's actually out there. A single `import` block with `for_each` over a
> CSV adopts all five records at once; that's the bulk path and it scales to
> hundreds. Then for the ruleset — a gnarly nested object nobody wants to
> hand-write — `terraform plan -generate-config-out` makes Terraform write the
> configuration itself."
>
> "Generated config is correct but ugly: null optionals, computed attributes
> echoed back, all noise. `normalize.py` strips it. Eighty-four lines here."

**DO** — point at **Plan: 5 to import, 0 to add, 0 to change, 0 to destroy**,
then **No changes** at the end

**SAY**

> "Read those counters out loud: zero to change, zero to destroy. Terraform
> took ownership of six live objects and altered none of them. Then the gate:
> the next plan says No changes. That sentence is the certificate."
>
> "Here's the war story, and it's why I insist on the gate. The first time I
> ran this, the plan said **five to change**. Adoption was about to silently
> rewrite five live records. The cause: the seeded TXT content had an em-dash
> in it, and Cloudflare stores non-ASCII in TXT records as octal escapes. So
> the config said one thing, the API held another, and Terraform was helpfully
> about to 'fix' the API to match my config."
>
> "On five lab records, who cares. On five hundred production records where
> the differences are TTLs and comments accumulated over years — that's an
> afternoon of unexplained changes and a very bad incident review. The gate
> caught it. That's the entire argument: nobody refactors, renames or
> restructures until the plan is quiet, because refactoring on top of a
> mismatch compounds the mismatch."

**IF ASKED**

- *"How long does this take for a real estate?"* — The import mechanics are
  fast. Reaching a quiet plan is the work, and it's iterative: plan, read the
  diff, decide whether the config or your understanding is wrong, repeat.
- *"Where's your remote state?"* — Honest answer: this lab runs on local
  state, and the CI pipeline uses a small separate environment owning one
  not-yet-existing resource, so empty state is the correct starting point.
  Remote state with locking is the next thing you'd add, and the reason is
  exactly the dual-writer problem in the next topic.

---

# 1:21 — TOPIC 32 — SHARP EDGES (13 min)

## Framing

**SAY**

> "Four failures. They look unrelated. They're the same disease at different
> altitudes, and I'll name it at the end rather than spoil it now."

## Sharp edge 1 — plan noise

**DO**
```bash
bash scripts/demo-32-noise.sh
```

**SAY** — point at the repeated **Plan: 0 to add, 1 to change**

> "I wrote a CNAME target the way every DNS textbook on earth says to write
> one: fully qualified, trailing dot. `example.com.` Cloudflare stores it
> without the dot."
>
> "So every plan compares my config against the API and proposes a change.
> Watch what happens when I do the obvious thing and apply it — still dirty.
> Apply again — still dirty. It never converges. That pipeline is never green
> again, and every plan any engineer runs from now on has a meaningless diff
> in it."
>
> "The real damage isn't cosmetic. You've trained your team to see a non-empty
> plan and think 'that's just the usual noise'. You've broken the signal. The
> next real, dangerous diff scrolls past next to the phantom one and gets the
> same shrug."
>
> "The tempting fix is `ignore_changes` on that attribute, and I want to spend
> a moment on why that's worse than the problem. `ignore_changes` doesn't
> silence the false diff — it tells Terraform to stop managing that attribute
> entirely. So when someone genuinely repoints this CNAME, out of band or in a
> bad pull request, your plan says nothing. You've traded a cosmetic annoyance
> for blindness on the single most important field on that record. The right
> fix is boring: write the value in the form the API stores."
>
> "One honest note. I originally built this demo around letter case, because
> that used to be a classic Cloudflare gotcha. Provider version 5 normalizes
> case now, so it doesn't reproduce — I found that out by running it. Same for
> TXT quote-wrapping. The trailing dot is the one that still bites. Verify
> your own gotchas against your own provider version, because they get fixed
> and you'll be telling people a story that isn't true anymore."

## Sharp edge 2 — dual writers

**DO**
```bash
bash scripts/demo-32-dual.sh
```

**SAY**

> "Two Terraform roots, one DNS record. Root A created it. Root B imported it
> — and importing is such an innocent-looking action. Somebody onboarding a
> new module runs an import to 'bring the record under management'."
>
> "Now watch. B applies its truth. A's next plan reports drift it cannot
> explain, and A's auto-apply heals it. Back and forth, forever, both
> pipelines green."
>
> "Same shape as the zone-settings flap, one layer up. And the detection story
> is genuinely interesting: when you investigate this with the audit log, the
> actor you find is *the other team's pipeline token*. That's your signal —
> drift attributed to a service credential rather than a human almost always
> means two writers, not a rogue admin."

## Sharp edge 3 — list scale

**SAY** *(no live run — the numbers are the demo)*

> "Same five hundred IP addresses, modelled two ways: one `cloudflare_list`
> resource holding an items collection, versus five hundred individual
> `cloudflare_list_item` resources. I measured both against this account."
>
> "The collection applies in fifty-one seconds, no-op plan in thirty-one. The
> per-item version: no-op plan takes forty-three seconds, destroy was still
> grinding after two minutes when I intervened — and the apply **did not
> complete at all**. Cloudflare rate-limited the individual POSTs, Terraform
> aborted partway, and left a list with four hundred and ninety-six of five
> hundred entries — matching neither the code nor the previous state."
>
> "So the headline isn't 'slower'. It's 'does not work'. And here's the number
> that lands hardest: deleting that entire list through one API call took two
> seconds. Terraform had to issue five hundred deletes because *you* told it
> these were five hundred independent resources."
>
> "The trade-off is real though — per-item resources buy per-item ownership,
> so different teams or modules can contribute individual entries. You pay for
> that on every plan, forever, plus a rate-limit cliff. One collection is fast
> and durable but has exactly one owner. Same ownership question again, and at
> five hundred entries the numbers decide for you."

## Sharp edge 4 — phase ownership

**DO**
```bash
bash scripts/demo-32-phase.sh
```

**SAY**

> "Two roots both declaring a ruleset for the same phase. Root A applies and
> owns it. Root B's apply fails."
>
> "And I want to argue this loud failure is the *best* outcome of the four.
> The API refused. Nobody's config silently won. Compare that to the
> dual-writer case where nothing errors for months."
>
> "The pathological part is what happens next, socially. B's pipeline is red,
> B's team is blocked, and somebody fixes it — by deleting A's ruleset in the
> dashboard, because that unblocks them in thirty seconds. Now B is green, and
> A's next apply recreates its own ruleset, breaking B again. That's the
> ping-pong: a people failure that a loud error message triggered."

## The synthesis

**SAY**

> "Here's the disease. Phase ownership, dual writers, the flapping setting,
> list scale — every one is a shared thing with two owners, or an ownership
> decision made without anyone noticing it was being made."
>
> "And the lesson underneath: the API referees loudly sometimes and not at all
> other times. The loud ones you fix in an afternoon, because your pipeline is
> red and you can't ignore it. The quiet ones run for months. So the quiet
> failures are the expensive ones, and the only defence is deciding ownership
> deliberately — before the API decides for you by accident."

---

# 1:34 — TOPIC 27 — DRIFT DETECTION (9 min)

## The problem

**SAY**

> "Drift is what happens between your applies. Someone clicks something during
> an incident and doesn't come back to codify it. A vendor changes a default.
> A different pipeline writes to something you own. Then two months later
> you're mid-incident and your config has stopped describing production."

**DO**
```bash
bash scripts/demo-27-make-drift.sh
```

**SAY**

> "I've just made a change via the API — the same call the dashboard makes
> when you click. The detector is one flag: `terraform plan
> -detailed-exitcode`. Zero means clean, one means error, two means drift.
> That's the whole mechanism, which means your drift detector is a scheduled
> workflow that checks an exit code."
>
> "But 'something changed' is a useless alert. The question anyone asks is
> *who*, and until you can answer that you can't fix the cause. So the plan is
> rendered to JSON and a script correlates the drifted resource against the
> Cloudflare audit log to name the actor. That turns a nag into a conversation
> with a specific person about a specific click."
>
> "Two honest notes. The attribution join needs an audit-log token permission
> that isn't granted in this lab — detection works, the naming isn't wired up
> today. And the workflow is dispatch-only rather than nightly here, because
> the scheduled version needs remote state, which we're deliberately running
> without."

**SAY** — the real point

> "Now the thing I actually want you to leave with. Detection is the
> consolation prize. If you're detecting drift, humans can still write to
> production, and you've accepted a permanent background rate of drift and
> built a machine to notice it."
>
> "The structural fix is removing the ability. In Cloudflare that's changing
> human dashboard roles to **Administrator Read Only** — people keep full
> visibility, they lose the pencil — and letting the pipeline's scoped token
> be the only credential that can write. Then drift isn't detected, it's
> impossible."
>
> "I'm not applying that here for an honest reason: this sandbox login is my
> only access, and locking myself read-only would end the demo. But that's the
> answer, and detection is what you run while you're negotiating your way
> toward it."

---

# 1:43 — TOPIC 14 — TUNNEL DESIGN (9 min, walkthrough)

**DO** — **Tab 5**, change URL to:
`https://github.com/miroslavt-arch/cf-terraform-lab/blob/main/infra/modules/tunnel-site/main.tf`

**SAY** — up front

> "I'm walking through this one rather than running it — the token in this lab
> can read tunnels but not create them, and I'd rather show you the design
> than fake it."

**DO** — point at `config_src = "cloudflare"`

**SAY**

> "First decision, and it's governance rather than technical: where does the
> tunnel's configuration live? You can run `cloudflared` with a local
> `config.yml`, which means the routing rules live on a box, edited by whoever
> has SSH. Or you set config source to Cloudflare, and the ingress rules
> become Terraform-managed API objects."
>
> "The second option makes the connector *stateless*. It holds no
> configuration — it's a process that dials out and asks what to do. And that
> single property gives you high availability for free: run the same token
> twice, kill either one, nothing happens. No leader election, no shared
> storage, no pets."

**DO** — point at the `ingress` list and the final `http_status:404`

**SAY**

> "Ingress rules match top to bottom, first match wins, and the catch-all must
> be last — `cloudflared` refuses a config whose final rule has a hostname.
> The module encodes that structurally, so nobody can append a rule after the
> catch-all and silently make it unreachable."

**SAY** — rotation

> "Now the part that separates people who've operated tunnels from people who
> haven't: rotating the credential."
>
> "The naive approach is changing the tunnel secret in place. Terraform plans
> a destroy and recreate. But the tunnel's ID is what your DNS record points
> at — so you've destroyed the thing your public hostname resolves to, and
> you're down from the moment apply starts until a new connector registers
> under a new ID. Minutes, if everything goes well."
>
> "The two-step version: bring up a *second* tunnel alongside the first, start
> connectors for it, and only then repoint the DNS record — an in-place
> content update, atomic at the edge. Then drain and remove the old one."
>
> "For that to work, the DNS record has to be owned by the *environment*, not
> the tunnel module — because if the module owns it, destroying the module
> destroys the record. That's a Topic 9 ownership decision showing up in an
> operational runbook, which is why these topics are in this order."

---

# 1:52 — CLOSE

**SAY**

> "Four of the things I showed you were failures on purpose, and they were all
> the same failure: a shared thing with two owners. A zone setting. A DNS
> record. A ruleset phase. A list of five hundred entries someone modelled as
> five hundred owners without deciding to."
>
> "The API tells you about some of these immediately and never tells you about
> others. The loud ones cost you an afternoon. The quiet ones run for months
> and surface during an incident, when you discover your config stopped
> describing production some time in the spring."
>
> "So: decide ownership deliberately. Make the rules executable rather than
> written down — a policy that isn't a check is a hope. And put the human
> approval where the credential is, not where the merge button is."

---

# RESET — only if you deliver again

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
```

Then get the two values for Step 4:
```bash
gh run list --limit 1 --json databaseId,headSha --jq '.[]|"plan_run_id=\(.databaseId) sha=\(.headSha)"'
```
