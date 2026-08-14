# Sharp edge 4 — plan noise: the API canonicalizes, your code doesn't

DNS names and CNAME targets are case-insensitive, and the Cloudflare API
**stores them lowercased**. Write `CDN.Example.COM` in your config and:

1. apply succeeds — the API accepts it and stores `cdn.example.com`
2. the next plan compares your `CDN.Example.COM` against the API's
   `cdn.example.com` and proposes an update
3. the update "succeeds", changes nothing, and the plan **never settles** —
   every run of every pipeline shows a phantom diff, forever

`noisy/main.tf` reproduces it; `fixed/main.tf` is the same record with the
content written in the API's canonical form — the diff vanishes.

Run: `scripts/demo-32-noise.sh`

**Why `ignore_changes` is the WRONG fix:** ignoring `content` doesn't just
hide the phantom diff — it stops Terraform managing the value at all. When
someone actually repoints the CNAME (out-of-band or in a bad PR), your plan
stays silent about the one field that matters most on this record. You paid
for drift-blindness to avoid a cosmetic itch. **Match the canonical form
instead** — and when a provider offers a normalized attribute or a
`lifecycle` alternative, prefer that.

**Reset:** the script destroys the demo record it created.
