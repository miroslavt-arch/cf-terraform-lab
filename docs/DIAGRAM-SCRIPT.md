# Diagram script — read this aloud

A spoken walkthrough of all thirteen diagrams in
[adoption-kit/ARCHITECTURE.md](../adoption-kit/ARCHITECTURE.md).

**How this is written.** Everything in a `>` block is meant to be *said*. Short
sentences on purpose — they are written to be spoken, not read silently. You
can read them word for word and it will sound like talking, not like reciting.

**POINT AT** tells you where to put your cursor. **[PAUSE]** means stop
talking and let them look. The pauses matter more than the words; people cannot
read a diagram and listen to you at the same time.

**Runs about 50 minutes** at a comfortable pace. Timings per diagram below. To
cut to 30, do diagrams 1, 2, 5, 8 and 13 only — that is the spine.

Open the file on GitHub so the diagrams render. Zoom the browser to 125%.

---

## Opening — before diagram 1  ·  1 min

> "I'm going to walk you through the architecture. Thirteen diagrams. Each one
> is a pattern you can adopt on its own — you don't need all of them, and I'll
> tell you which ones to do first."
>
> "Everything I show you is in the repo you're getting. The diagrams, the
> workflows, the policies, the tests. It's not slideware. You can clone it this
> afternoon."

[PAUSE]

> "One idea runs through all of it, so let me say it once up front. Every
> pattern here does the same thing. It says no, cheaply, as early as possible."
>
> "That's it. That's the whole architecture. The rest is detail."

---

## 1 · The whole system  ·  4 min

**POINT AT** the four boxes, left to right, as you name them.

> "Four zones. Let's go left to right, because left to right is also cheapest
> to most expensive."
>
> "First box — the engineer's laptop. Seconds. You write code, and two things
> check it before it goes anywhere. Module validation rejects bad input. And
> pre-commit catches secrets, formatting, policy."

**POINT AT** the second box.

> "Second box — the pull request. Minutes. Tests run with no credentials at
> all. Policy gets linted. Then a plan, and I want you to notice the words
> *read-only credential*. We'll come back to that. A destroy guard checks the
> plan. And the plan gets saved as an artifact."

**POINT AT** the third box.

> "Third box — a human. Somebody with a name approves it. Only then does the
> apply run."

**POINT AT** the bottom box.

> "Fourth box — the clock. Three jobs that nobody triggers. Drift detection
> nightly. An invariant check hourly. Contract tests nightly. Nobody remembers
> to run these, which is exactly why they're on a schedule."

[PAUSE — let them take in the whole picture]

**POINT AT** the dotted lines from live infrastructure.

> "See the dotted lines coming back? That's the part most people skip. The
> pipeline pushes changes out. These read reality back and compare it to what
> you think you deployed."
>
> "A pipeline that only pushes is a one-way conversation. You find out you were
> wrong during an incident."

**The line to land:**

> "The reason the layers are ordered this way is cost. Catching a mistake in
> your editor costs seconds and involves one person. Catching it in production
> costs a night and involves everyone. Every layer down is about ten times the
> one above."

---

## 2 · The gated pipeline  ·  6 min  ·  **the important one**

Give this one room. It's the pattern most worth adopting.

> "This is a sequence diagram. Time runs downward. Let me set up the problem
> first."

[PAUSE — don't point yet]

> "Here's a failure everybody in this room has lived through. A reviewer
> approves a plan. The pipeline runs. But between the approval and the apply,
> something changed — someone merged, someone touched a console. So the
> pipeline computes a *fresh* plan and applies that one."
>
> "What executed is not what was approved. Nobody lied. The process just has a
> hole in it."

**POINT AT** the top half, the terraform-pr participant.

> "Two ideas close that hole. Here's the first."
>
> "The plan on the pull request is made with a **read-only** credential. It
> physically cannot write. And the result is saved — right here — as an
> artifact named after the commit hash."

**POINT AT** the artifact store.

> "That name is the contract. `tfplan-` and then the commit SHA."

**POINT AT** the dispatch arrow and the "job STOPS here" note.

> "Now the second idea. Somebody dispatches the apply. And the job stops."
>
> "Not slow. Stopped. It has no write credential yet."

[PAUSE — this is the beat that lands]

> "The write token isn't in the repository. It lives inside a GitHub
> environment, and GitHub does not hand that environment to the job until a
> named human approves. So unreviewed code can't reach the credential. Not
> because a policy forbids it. Because it isn't there."

**POINT AT** the final arrow — apply THAT FILE.

> "And when it does run, look at what it does. It downloads the artifact and
> applies *that file*. There is no plan command in the apply workflow. None. I
> deleted it on purpose."
>
> "So it's structurally incapable of applying something the reviewer didn't
> see."

**The bonus, worth thirty seconds:**

> "You get one more thing free. If the world moved between the plan and the
> apply, Terraform itself refuses. The error says *saved plan is stale*."
>
> "That's not our policy. That's the tool. Process can be skipped. This can't."

**If someone asks "isn't the manual step a bottleneck?"**

> "It is, and that's the product. If you automate the approval you've built a
> pipeline that applies whatever it computes, which is where we started. The
> one-minute timer is there so somebody can say 'wait, wrong environment.'"

---

## 3 · Two-tier testing  ·  4 min

**POINT AT** the left box.

> "Two tiers. Left side runs on every push. Right side runs nightly."
>
> "Left side — the provider is mocked. No credentials. No network. About one
> second."

[PAUSE]

> "That one second is not a nice-to-have. It's the whole reason this survives.
> A test suite that takes ten minutes gets skipped within a month. And a
> skipped suite is worse than no suite, because you still believe it's
> protecting you."

**POINT AT** what tier one catches.

> "What does a mocked test actually catch? Ordering. Validation. Defaults.
> Composition. All the logic *you* wrote. That's most of your bugs."

**POINT AT** the right box.

> "Right side — real provider, real API, real resources. Minutes, not seconds."
>
> "Why bother? Because a mock can't tell you what the API actually does with
> your input. Whether it rewrites a value. Whether it rejects a combination.
> Those are real, and they only show up against the real thing."

**POINT AT** auto-destroy.

> "Every resource it creates carries a reserved prefix, and it destroys them
> when it finishes. The prefix is what makes automatic destruction safe to
> allow — our destroy guard recognises it."

**Worth saying, because it will save them a day:**

> "Two traps when you write these. First, declare your variables inside the
> test file. If you don't, Terraform parses your environment variable as an
> expression, and a zone name like `example.com` dies with 'extra characters
> after expression', which tells you nothing."
>
> "Second, `terraform init` needs the test-directory flag too, not just
> `terraform test`. Otherwise you get 'module not installed' at run time, and
> it reads like a broken test rather than a missing flag."
>
> "Both of those are written in the comments. I hit both of them this week."

---

## 4 · Module contracts  ·  4 min

**POINT AT** the two red boxes on the left.

> "A module is an API. And if the only way to find out you passed the wrong
> thing is a five-hundred error from the provider three minutes into an apply
> — that's a bad API."
>
> "Two gates before anything reaches the network. Both red boxes here are
> rejections that cost about a second."

**POINT AT** the first diamond.

> "First gate is the type system. One map of objects, with optional defaults.
> Not a dozen loose variables. Callers pass what they mean."

**POINT AT** the second diamond.

> "Second gate is validation blocks, and this is the one people don't write."
>
> "The type system knows what Terraform allows. Only *you* know what your
> organisation allows. Naming conventions. Bounded sets. Allow-lists. That
> knowledge has to live somewhere, and if it lives in a wiki page it isn't a
> rule, it's a hope."

[PAUSE]

> "And write the message properly. Name what's allowed, and say why. A
> validation that just says 'invalid input' teaches nobody anything. Writing
> the sentence is the work."

**POINT AT** the pinning box.

> "Last thing, and it's the cheapest win on this whole diagram. Pin your module
> by tag. Question mark ref equals v1.2.0."
>
> "A relative path or a branch means your environment changes when somebody
> else pushes. A tag means upgrading is a commit you make on purpose. It shows
> up in a diff. You can revert it."
>
> "Almost nobody does this, and it costs one line."

---

## 5 · Singleton ownership  ·  5 min  ·  **the one they'll recognise**

**POINT AT** the top half — the red one.

> "Top half is broken. Bottom half is fixed. Let me show you the broken one
> first, because you've all lived it."
>
> "Some things are singletons. There's exactly one minimum TLS version for a
> zone. Not one per team. One."

**POINT AT** the two roots pointing at the shared object.

> "Two Terraform roots both declare it. Root A wants 1.2. Root B wants 1.3."

[PAUSE]

> "Now — what happens when both of them apply?"

[PAUSE — let somebody answer]

> "Both succeed."
>
> "Both. Each one silently reverts the other. Both pipelines stay green. And
> they'll keep flipping it back and forth forever."

**POINT AT** the dotted feedback arrows.

> "Every night, A's plan sees drift it can't explain, and heals it. Then B's
> plan sees drift, and heals it back."
>
> "Nothing errors. Nothing warns. That's what makes this class of bug
> expensive. It runs for months, and you find it during an incident, when
> you're trying to work out why a setting won't stay put."

**POINT AT** the bottom half.

> "The fix isn't clever. It's a boolean."
>
> "Exactly one root sets manage-settings to true. Everyone else consumes the
> module for the other parts. Default is false, so the dangerous case has to be
> typed by somebody and reviewed by somebody."

**The question you will get — have this ready:**

> "Somebody's going to ask why not just use `ignore_changes`. Don't."
>
> "It stops managing the field entirely. So you'd stop seeing a *real*
> unauthorised change to the same setting. You'd trade a cosmetic annoyance for
> blindness on exactly the field you were worried about."

---

## 6 · Composition from fragments  ·  4 min

**POINT AT** the three fragment files.

> "Several teams need rules in one shared object. Incident response. Security.
> An app team."
>
> "One file per team. That single decision kills the merge conflicts, because
> teams touch different files."

**POINT AT** the concat node.

> "Then they're concatenated in a fixed order. Incident first, always."
>
> "And the reason incident is first is that this line says so. Not because
> three teams remembered a convention. It's structural."

**POINT AT** the policy and CODEOWNERS arrows.

> "Two more things hang off this. Policy lints each fragment for what that team
> is allowed to do. And CODEOWNERS routes each file's review to its team."

[PAUSE]

**The story — this is the memorable bit:**

> "Let me give you the real example, because it's the one that convinced me."
>
> "The app team's load tests kept getting challenged by the WAF. Annoying,
> reasonable complaint. They asked for a rule that skips the WAF for their
> load-test tool. Perfectly sympathetic request."

[PAUSE]

> "But remember the order. Incident, then security, then app. A skip in the
> *last* fragment doesn't skip the app team's rules. It skips everything
> **above** it."
>
> "So during an incident, when we've armed the kill switch to challenge all
> traffic — anything with 'loadtest' in the user agent walks straight through."

[PAUSE]

> "Nobody was being careless. They asked for a narrow exception and reached for
> a mechanism that was much wider than they realised. That's the normal case,
> not the exotic one."
>
> "The policy catches it in about a second and tells them to use `log` instead
> — which gives them the visibility they actually wanted."

**One more, thirty seconds:**

> "There's a meta-test in the pipeline. It runs the policy against a file we
> know is bad, and fails the build if it *passes*."
>
> "Because a lint that's quietly stopped linting is worse than no lint. You
> trust it."

---

## 7 · The kill-switch  ·  3 min

**POINT AT** the state diagram.

> "Three states. Peacetime, elevated, lockdown. One variable moves between
> them."
>
> "The emergency rules are already written. Already reviewed. Already deployed.
> And disabled."

[PAUSE]

> "Because at three in the morning during an incident, you do not want to be
> writing new Terraform. You want to flip one variable."

**POINT AT** the peacetime state text.

> "Now here's the half people skip."
>
> "Every team is good at arming. Nobody is good at disarming. The incident ends
> at four, everyone goes to bed, and a challenge stays on production for three
> weeks until a customer complains."

**POINT AT** the "hourly check FAILS" lines.

> "So there's an hourly job. And it asks the **API** what's enabled. Not the
> tfvars."
>
> "That matters. Tfvars describe intent. Intent is exactly what's wrong when
> somebody armed something by hand in a console."

[PAUSE]

> "If anything's still armed, the job fails. A failing scheduled workflow
> emails the owner and puts a red X on the Actions tab. Every hour. Until
> somebody disarms."
>
> "The nagging is the feature."

**The generalisation — say this, it's what makes it stick:**

> "This shape isn't about WAF rules. It's a maintenance page still being
> served. A feature flag left forced. A firewall rule opened just for the
> migration. Debug logging left at TRACE."
>
> "Anything you turn on during an emergency and mean to turn off."

---

## 8 · Drift detection  ·  5 min

**POINT AT** the exit code diamond.

> "This whole diagram hangs off one thing that most people never use."
>
> "`terraform plan` has a flag called detailed-exitcode. And it returns three
> different codes."

**POINT AT** each branch as you say it.

> "Zero — clean. Code and reality agree."
>
> "One — error. The plan itself is broken. That's not drift, that's a bug."
>
> "Two — **the world moved**."

[PAUSE]

> "Exit code two is the entire trick. That's the one you put on a cron."

**POINT AT** the cron node.

> "And it has to be a schedule. Not a PR check."
>
> "Because drift doesn't happen when you push. It happens at two in the
> morning during an outage, when someone with console access fixes something by
> hand — correctly, and for good reasons."
>
> "A check that only runs when code changes will never see it."

**POINT AT** the read-only note if you're on the workflow file.

> "It runs with the read-only credential. Noticing something is wrong should
> never require the ability to change it."

**POINT AT** the report and audit nodes.

> "When it fires, it renders what changed and — if your provider has an audit
> API — who changed it and when."

**Be honest here:**

> "I'll flag something. In our lab, the audit lookup returns a 403 — the token
> needs one more permission. So the detection works and the attribution
> doesn't."
>
> "The script says that in one line rather than pretending. And that step is
> marked continue-on-error, deliberately: attribution failing must never hide
> detection."

**POINT AT** the FAIL node.

> "Last thing. It fails. It doesn't warn."
>
> "A drift job that goes green with a warning gets ignored within two weeks.
> Ask me how I know."

---

## 9 · Brownfield adoption  ·  4 min

**POINT AT** the top node.

> "Nobody starts greenfield. You inherit an estate somebody built by hand, and
> you have to bring it under Terraform without an outage — because these are
> live DNS records."

**POINT AT** each step as you walk down.

> "Discover what exists. Write import blocks — and use *import blocks*, not the
> old `terraform import` command."

[PAUSE]

> "That's worth a sentence. The old command was a one-shot you ran by hand, in
> the right order, against the right workspace, and hoped. It left no trace in
> code. Import blocks are ordinary configuration. They appear in the diff. They
> get reviewed. You can loop over a list."

**POINT AT** generate-config-out.

> "Then Terraform writes the HCL for you. It's correct, and it's unreadable —
> machine-generated names, every attribute spelled out."
>
> "So normalise it. Because if you skip that, nobody will ever touch the file
> again, and you've swapped an undocumented estate for an unmaintainable one."

**POINT AT** the gate diamond — the yellow one.

> "And here's the step people skip. This one."

[PAUSE]

> "Adoption is not finished when the import applies. It's finished when a
> **fresh plan says no changes**."
>
> "Until then you have two descriptions of one estate, and you don't know which
> one is true. Make it a hard gate in CI — not a habit, not a checklist item.
> The pipeline exits one if the plan isn't clean."
>
> "Only after that should anyone rename anything. Refactoring on top of an
> uncertain baseline is how adoptions cause the outage they were supposed to
> avoid."

---

## 10 · Tunnel HA  ·  3 min

**POINT AT** the outbound arrows.

> "A tunnel is an outbound-only connection from your network to the edge."
>
> "No inbound firewall rule. No public IP. Nothing about your origin is
> reachable from the internet except through this."

**POINT AT** the two connectors.

> "The interesting part isn't creating one. It's running one without a single
> point of failure."
>
> "Two connectors. One tunnel. Same token on both. The edge load-balances
> across whichever ones are healthy."
>
> "Kill one — traffic keeps flowing. No config change, no DNS change. That's a
> good thing to demo live if you ever get the chance."

**Say the honest bit:**

> "I should flag: this one I'm showing you from the module rather than from a
> live run. Our lab token could read tunnels but not create them. It's marked
> unverified in the kit. Test it in your own account before you rely on it."

---

## 11 · Tunnel rotation  ·  2 min

**POINT AT** the sequence, top to bottom.

> "Rotation. Four steps, and the order is the whole point."
>
> "Stand the new tunnel up alongside the old one. Move DNS. Drain. Then
> delete."

[PAUSE]

> "The wrong way is delete-then-create. And Terraform will happily do exactly
> that in a single apply if you just change the name in your config."
>
> "There's a window with zero healthy connectors. That window is an outage, and
> it's longer than you think, because DNS caches."

**POINT AT** the note at the top.

> "Never fewer than one healthy connector. At any point. That's the rule, and
> it's why this needs a runbook rather than a code comment."

---

## 12 · The sharp edges  ·  5 min

> "Four things that cost me real time and that no tutorial mentions. I'll go
> fast."

**POINT AT** the first box.

> "One — plan noise. I wrote a CNAME without a trailing dot. The API stores it
> *with* one."
>
> "Now every plan shows a diff. Applying doesn't converge. The pipeline is
> never green again."
>
> "The fix is to write the canonical form — what the API will actually store."

[PAUSE]

> "And do **not** reach for `ignore_changes` here. It would silence the diff by
> no longer managing that field at all — so a genuine repoint of that CNAME
> would also pass unnoticed. You'd trade a cosmetic itch for blindness on the
> field that matters most."

**POINT AT** the second box.

> "Two — dual writers. Same as the singleton problem, different object. B
> overwrites A. A heals it back. Forever. Both green."

**POINT AT** the third box.

> "Three — phase ownership. Two roots claim the same slot, and the second one
> **fails loudly**."
>
> "And that's the good outcome. The slot is taken, the API says so."

[PAUSE]

> "The bad part is what happens next. B's team deletes A's object in the
> console so their pipeline goes green. Then A's next apply recreates it."
>
> "Now you have ping-pong *and* a deletion nobody reviewed."

**POINT AT** the fourth box.

> "Four — list scale. Five hundred items modelled as five hundred resources
> means five hundred API reads per plan. The same five hundred as items inside
> one resource is a single read."
>
> "Model the collection as the unit when the provider gives you both. Those
> numbers are measured, not demonstrated — flagged in the kit."

---

## 13 · Adoption order  ·  3 min  ·  close on this

**POINT AT** the sequence left to right.

> "Last diagram. You don't need all ten of these, and doing them out of order
> wastes effort. So here's the order I'd actually recommend."

**POINT AT** each as you go.

> "One — the destroy guard. Highest value per line in the whole kit, and you
> can try it this afternoon against a plan you already produce. No pipeline
> changes needed."
>
> "Start strict. Allow nothing, see what your real plans trip, widen
> deliberately. Starting permissive and tightening later does not happen."

> "Two — tier-one tests. They're what makes everything after this safe to
> change."

> "Three — the gated pipeline. The big one. Do it once tests exist."

> "Four — drift detection. Now that your code is trustworthy, go find out where
> reality disagrees."

> "Five — module contracts, as your modules stabilise."

> "Six — the rest, as the problems actually show up."

[PAUSE]

> "That last one is genuine advice. Adopting a pattern for a problem you don't
> have is how platform teams lose credibility. Wait until somebody's been
> bitten. Then the pattern sells itself and you don't have to."

---

## Closing  ·  1 min

> "So — thirteen diagrams, ten patterns, and one idea."
>
> "Every one of them says no, cheaply, at the earliest layer that can catch
> that kind of mistake. A validation block costs a second and one person's
> attention. A production incident costs a night and everyone's."
>
> "Each layer down is roughly ten times the one above. That's the entire
> argument for pushing checks left."

[PAUSE]

**The last line — say it slowly:**

> "And notice what none of these were. None of them were a document. Not one."
>
> "Every single one exits non-zero. A policy that isn't a check is a hope. And
> hope doesn't survive a deadline."

---

# Cue card

Tear-off version. Diagram, the beat, the sentence.

| # | Diagram | The one line |
|---|---|---|
| 1 | whole system | "Every layer down costs ten times the one above" |
| 2 | gated pipeline | "It's not slow. It's stopped. It has no credential yet" |
| 3 | two tiers | "A suite that takes ten minutes gets skipped in a month" |
| 4 | module contracts | "A rule in a wiki page isn't a rule, it's a hope" |
| 5 | singletons | "Both applies succeed. That's the problem" |
| 6 | fragments | "A skip in the last fragment skips everything above it" |
| 7 | kill-switch | "Everyone's good at arming. Nobody's good at disarming" |
| 8 | drift | "Exit code two means the world moved. Put it on a cron" |
| 9 | brownfield | "Not finished when it applies. Finished when a fresh plan is clean" |
| 10 | tunnel HA | "Kill one connector, traffic keeps flowing" |
| 11 | rotation | "Never fewer than one healthy connector, at any point" |
| 12 | sharp edges | "ignore_changes trades a cosmetic itch for real blindness" |
| 13 | adoption order | "Adopting a pattern for a problem you don't have loses you credibility" |

**If you only have 30 minutes:** 1, 2, 5, 8, 13.

**If somebody challenges the whole approach** — "this is a lot of process":

> "Fair. So pick one. The destroy guard is about forty lines and it runs
> against a plan you already produce. If it never fires, you've lost an
> afternoon. If it fires once, it's paid for itself and everything else in the
> kit."
