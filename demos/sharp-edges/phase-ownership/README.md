# Sharp edge 1 — phase ownership

A zone gets **one** entrypoint ruleset per phase. Two roots that both declare
a `cloudflare_ruleset` for the same phase are fighting over a singleton slot:

- Root A applies first and owns the phase. Green pipeline.
- Root B's apply **fails** — `"a ruleset for this phase already exists"`.
- B's team "fixes" it: deletes A's ruleset in the dashboard, or imports it.
- A's next nightly plan shows its ruleset gone (or hijacked) and recreates it.
- Now B is broken again. Repeat forever — the ping-pong.

`root-a/` and `root-b/` both target the **`http_request_firewall_managed`**
phase - chosen so the demo never touches `http_request_firewall_custom` (owned
by the real `lab-waf-composed` ruleset) or `http_ratelimit` (owned by the
Topic 29 legacy ruleset). The lab's apply token also deliberately lacks
transform-phase permission, which is why the transform phases are not used. Run: `scripts/demo-32-phase.sh`

**Fix:** phases are owned like settings are owned (Topic 9): ONE root per
phase, other teams contribute **fragments** to it (Topic 10), never their own
ruleset resource.

**Reset:** the script destroys root A's ruleset at the end; root B never
succeeds in creating anything.
