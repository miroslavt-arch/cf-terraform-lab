# DEMO SCRIPT — click by click

No setup is shown. Everything already exists. You demonstrate, you explain.
Each step is either **DO** (a click or a paste) or **SAY** (what comes out of
your mouth). Do not improvise the commands — they are copy-paste exact.

---

## BEFORE YOU SHARE YOUR SCREEN (2 minutes, alone)

1. **DO** — Open a terminal. Paste:
   ```bash
   source ~/.cf-lab-env && cd "D:/Work/Claude/Shared Subnet Diagram/cf-terraform-lab" && clear
   ```
2. **DO** — Make the terminal font big. Ctrl and `+`, four or five times.
3. **DO** — Open Chrome. Open these four tabs, left to right, in this order:
   - **Tab 1** — https://github.com/miroslavt-arch/cf-terraform-lab/pull/2
   - **Tab 2** — https://github.com/miroslavt-arch/cf-terraform-lab/actions
   - **Tab 3** — https://github.com/miroslavt-arch/cf-terraform-lab/settings/environments
   - **Tab 4** — https://dash.cloudflare.com/bc682468ed596d21ce506ecbae4cb9a4/gracious-binary.sxplab.com/dns/records
4. **DO** — Un-minimize the Chrome window fully. Do not leave it minimized.
5. **DO** — Share your screen.

---

# PART 1 — THE PIPELINE (18 min)

## 1.1 Show the plan that CI produced

1. **DO** — Go to **Tab 1** (the pull request), *Conversation* tab. Scroll to
   the comment headed **Terraform plan for cbc0a374**.
2. **DO** — Click the grey triangle labelled **plan output** to expand it.
3. **SAY** — *"This plan was not produced by me. A GitHub Action produced it
   when I opened this pull request, and posted it here as a comment."*
4. **DO** — Point at the line beginning **Artifact: tfplan-cbc0a374...**
5. **SAY** — *"Notice the artifact is named after the commit SHA. That file is
   what my reviewer is approving. Hold on to that — it matters in ninety
   seconds."*

## 1.2 Show that the planning job cannot write

6. **DO** — Go to **Tab 3** (Settings → Environments). Click **lab-plan**.
7. **DO** — Point at **Environment secrets** — one secret,
   `CLOUDFLARE_API_TOKEN_PLAN`.
8. **SAY** — *"The job that made that plan runs in this environment. The only
   Cloudflare credential it can see is a read-only token. It is not that we
   trust the plan job — it is that the plan job is incapable of writing.
   Planning is safe by construction."*

## 1.3 Show the gate itself

9. **DO** — Click **Environments** in the breadcrumb, then click **lab-apply**.
10. **DO** — Point at **Required reviewers** (your name) and **Wait timer**
    (1 minute).
11. **DO** — Scroll down. Point at **Environment secrets** —
    `CLOUDFLARE_API_TOKEN`.
12. **SAY** — *"This is the environment that can write. A required reviewer, a
    wait timer, and the write token — all in the same box. A job does not get
    the token until it gets through the gate."*

## 1.4 Fire the apply

13. **DO** — Switch to the terminal. Paste this as one line:
    ```bash
    gh workflow run tf-apply.yml --repo miroslavt-arch/cf-terraform-lab -f plan_run_id=32466152247 -f sha=cbc0a3746ffa6db94127353df0706375bfc877af
    ```
14. **SAY** — *"I am handing it two things: which run produced the plan, and
    which commit it was for. Nothing else."*

## 1.5 Watch the gate hold

15. **DO** — Go to **Tab 2** (Actions). Press **F5**. Click the top run, named
    **tf-apply**.
16. **DO** — Point at the yellow **Waiting** status and the
    **Deployment protection rules** box.
17. **SAY** — *"Nothing is running. The wait timer is counting, and after that
    it needs my approval. If I walked away right now, nothing would ever reach
    Cloudflare."*
18. **DO** — The **Review deployments** button appears after about 60 seconds.
    Fill that minute with 1.6 below.

## 1.6 Fill the wait — the invariant underneath

19. **SAY** — *"While that timer runs, let me show you why the artifact
    matters. A saved plan is a contract with the exact state it was computed
    from."*
20. **DO** — In the terminal, paste:
    ```bash
    bash scripts/demo-20-stale-plan.sh
    ```
21. **DO** — When the red error appears, stop talking and let people read it.
    Point at **Error: Saved plan is stale**.
22. **SAY** — *"I saved a plan. Someone changed a record behind my back.
    Terraform refused to apply the plan my reviewer approved. Process can be
    skipped. This cannot."*

## 1.7 Approve, and watch it land

23. **DO** — Back to **Tab 2**. Click the green **Review deployments** button.
24. **DO** — In the popup, tick the **lab-apply** checkbox.
25. **DO** — Click **Approve and deploy**.
26. **DO** — Click into the running job. Expand the step
    **download the EXACT plan artifact**, then
    **apply the pinned plan — NOT a fresh plan**.
27. **SAY** — *"It downloaded the artifact. It did not re-plan. What was
    approved is what executed — byte for byte."*
28. **DO** — Go to **Tab 4** (Cloudflare DNS). Press **F5**.
29. **DO** — Point at the new record **lab-ci-demo**.
30. **SAY** — *"A human approved a plan, and a machine applied exactly that
    plan. That is the whole pattern."*

---

# PART 2 — THE TOPICS (one paste, one line, each)

Run these from the terminal in order. Press Enter on a blank line between
each so the previous output stays readable.

## 2.1 — Tests that cost nothing (Topic 24)

31. **DO** — Paste:
    ```bash
    bash scripts/demo-24-unit-tests.sh
    ```
32. **DO** — Point at the line **real 0m0.3xxs**.
33. **SAY** — *"No token. No network. Five tests in a third of a second. There
    is no meeting where anyone argues about whether we can afford to run these
    on every pull request."*

## 2.2 — The module is a contract (Topic 7)

34. **DO** — Paste:
    ```bash
    bash scripts/demo-07-validation.sh
    ```
35. **DO** — Point at the red **Invalid value for variable** block.
36. **SAY** — *"That message was written by the module author. It fired at plan
    time, in my terminal, before anything touched Cloudflare. Validation is
    documentation that executes."*
37. **DO** — Paste:
    ```bash
    git diff v0.1.0 v0.2.0 -- infra/modules/zone-baseline/variables.tf
    ```
38. **SAY** — *"Consumers pin a tag, not a branch. That is the entire upgrade
    between two versions: one optional input. Optional means every existing
    caller upgrades with a zero-change plan."*

## 2.3 — Composition and ownership (Topic 10)

39. **DO** — Paste:
    ```bash
    bash scripts/demo-10-fragment-lint.sh
    ```
40. **DO** — Point at the two red **FAIL** lines.
41. **SAY** — *"Three teams contribute fragments to one ruleset, and the order
    is guaranteed by a single concat line — incident, then security, then app.
    The app team just tried to ship a skip action, and the lint stopped it with
    a message that explains why. That failure lands on their pull request, not
    on the merged ruleset."*

## 2.4 — Singletons need one owner (Topic 9)

42. **DO** — Paste:
    ```bash
    bash scripts/demo-09-singleton-flap.sh
    ```
43. **DO** — Point at the three values as they print: `high`,
    `essentially_off`, `high`.
44. **SAY** — *"Two Terraform roots both believe they own this one setting.
    Neither errors. Both pipelines are green. The value flaps forever, and what
    the dashboard shows depends on who applied last."*

## 2.5 — Kill switches (Topic 11)

45. **DO** — Paste:
    ```bash
    bash scripts/demo-11-arm.sh
    ```
46. **DO** — Point at **ARMED at the edge in 6 seconds**.
47. **SAY** — *"Incident declared. I did not write a firewall rule just now.
    That rule was written months ago, reviewed in daylight, and has been
    sitting in the ruleset disabled ever since. I flipped one word in a
    variables file. Six seconds from declaration to live at the edge — and six
    seconds back."*

## 2.6 — Brownfield adoption (Topic 29)

48. **DO** — Paste:
    ```bash
    bash scripts/demo-29-adopt.sh
    ```
49. **DO** — Point at **Plan: 5 to import, 0 to add, 0 to change, 0 to
    destroy**, then at **No changes** at the end.
50. **SAY** — *"Six resources Terraform had never heard of, made by raw API
    calls the way a dashboard user would. Zero changed. Zero destroyed. And the
    next plan says No changes. That sentence is the certificate that adoption
    touched nothing — and nobody refactors until they see it."*

## 2.7 — Sharp edges (Topic 32)

51. **DO** — Paste:
    ```bash
    bash scripts/demo-32-noise.sh
    ```
52. **DO** — Point at the repeated **Plan: 0 to add, 1 to change** lines.
53. **SAY** — *"I wrote a CNAME target with a trailing dot, the way every DNS
    textbook says to. Cloudflare stores it without. Applying does not fix it —
    watch: apply, still dirty; apply again, still dirty. This pipeline is never
    green again."*
54. **SAY** — *"And the tempting fix, ignore_changes, is worse. You stop
    managing that field entirely, so a real repoint of this record would also
    go unnoticed. You would trade a cosmetic itch for blindness on the field
    that matters most."*
55. **DO** — Paste:
    ```bash
    bash scripts/demo-32-dual.sh
    ```
56. **SAY** — *"Two roots, one DNS record. Nobody errors, ever. Each team sees
    the other as drift. Both pipelines stay green while the value flips back
    and forth forever."*

## 2.8 — Drift with a name attached (Topic 27)

57. **DO** — Paste:
    ```bash
    bash scripts/demo-27-make-drift.sh
    ```
58. **DO** — Point at **exit code 2 — drift detected**.
59. **SAY** — *"One flag is the whole detector: plan, detailed exit code, two
    means drift. But 'something changed' is a useless alert, so the report
    joins the drifted resource against the Cloudflare audit log to name the
    human who did it."*
60. **SAY** — *"And detection is the consolation prize. The real fix is
    structural: make humans read-only in the dashboard, and let only the
    pipeline's scoped token write."*

## 2.9 — Proof it runs unattended

61. **DO** — Go to **Tab 2** (Actions). Click **killswitch-reminder** in the
    left sidebar.
62. **DO** — Point at the column of green checks going back hours.
63. **SAY** — *"That has run every hour all night without me. It asks the
    Cloudflare API whether any kill switch is still armed, and it fails loudly
    for as long as one is. It checks reality, not intent."*

---

# CLOSING LINE

64. **SAY** — *"Four of the things I showed you were failures on purpose.
    Phase ownership, dual writers, the flapping setting, the never-settling
    plan — they are the same disease at different altitudes: a shared thing
    with two owners. The API referees loudly sometimes and not at all other
    times, and the quiet ones are the expensive ones."*

---

# IF SOMEONE ASKS ABOUT TUNNELS (Topic 14)

65. **DO** — Open `infra/modules/tunnel-site/main.tf` in your editor.
66. **SAY** — *"Config source is Cloudflare, not a file on a box — so the
    connectors are stateless and you get HA by simply running two of them. The
    ingress catch-all has to be last, and the module enforces that
    structurally. Rotation is two steps: bring up a parallel tunnel, then cut
    the DNS record over in place, because the environment owns that record, not
    the module. The naive version destroys the tunnel your DNS is pointing
    at."*
67. **SAY** — *"I am not running it live today — the token in this lab has read
    access to tunnels but not create."*

---

# RESET (only if you deliver a second time)

68. **DO** — Paste the whole block:
    ```bash
    source ~/.cf-lab-env
    cd "D:/Work/Claude/Shared Subnet Diagram/cf-terraform-lab"
    zid=9e9f552861413a5b624357be77e3516b
    rid=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/zones/$zid/dns_records?name=lab-ci-demo.lab.$LAB_ZONE" | jq -r '.result[0].id')
    curl -s -X DELETE -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/zones/$zid/dns_records/$rid" >/dev/null
    git checkout -- infra/envs/lab/main.tf 2>/dev/null
    bash scripts/arm-killswitch.sh none >/dev/null
    terraform -chdir=infra/envs/lab apply -auto-approve -input=false >/dev/null
    echo "reset complete"
    ```
69. **DO** — Open a fresh pull request so the pipeline has something to gate:
    ```bash
    git checkout main && git checkout -b demo/run2 && sed -i 's|default     = ".*"|default     = "second delivery"|' infra/envs/ci-demo/main.tf && git commit -qam "demo: run 2" && git push -u origin demo/run2 && gh pr create --fill
    ```
70. **DO** — Wait for the plan to go green, then get the new pair of values:
    ```bash
    gh run list --limit 1 --json databaseId,headSha --jq '.[]|"plan_run_id=\(.databaseId) sha=\(.headSha)"'
    ```
    Use those two values in step 13.
