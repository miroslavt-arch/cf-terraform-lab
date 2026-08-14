# Sharp edge 4 — plan noise: the API canonicalizes, your code doesn't

Write a CNAME target the way every DNS textbook says to — fully qualified,
with the trailing dot, `example.com.` — and Cloudflare's API stores it
**without** the dot. From then on:

1. apply succeeds; the record is correct in the dashboard
2. the next plan compares your `example.com.` against the API's
   `example.com` and proposes an update
3. that update "succeeds", changes nothing, and the plan **never settles** —
   every run of every pipeline shows the same phantom diff, forever

```
~ content = "example.com" -> "example.com."
Plan: 0 to add, 1 to change, 0 to destroy.
```

**Verified reproducing on cloudflare provider v5.23.0, 2026-08-14** —
including across repeated applies (the diff survives apply #1 and apply #2).

`noisy/main.tf` reproduces it; `fixed/main.tf` is the same record written in
the API's canonical form. Run: `scripts/demo-32-noise.sh`

## Why `ignore_changes` is the WRONG fix

Ignoring `content` doesn't just hide the phantom diff — it stops Terraform
managing the value at all. When someone actually repoints the CNAME (out of
band, or in a bad PR), your plan stays silent about the single most important
field on the record. You'd trade a cosmetic itch for drift-blindness on the
thing you most need to see. **Match the canonical form instead.**

## Note for instructors: what does NOT reproduce on v5

Older Cloudflare provider gotchas that are now fixed — checked live on
v5.23.0, so don't promise them on stage:

- **DNS name/target case** (`LAB-App.LAB.example.com`) — the provider
  normalizes case itself; no diff.
- **TXT content quoting** (writing `hello` where the API stores `"hello"`) —
  handled by the provider; no diff.
- **IP list items with `/32`** — doesn't produce noise, it produces a hard
  validation error: `IPv4 /32 CIDRs should have the /32 suffix stripped`.
  Nice teaching aside: the API refuses rather than silently canonicalizing.

The trailing dot is the one that still bites.

**Reset:** the script destroys the demo record it created.
