# Sharp edge 2 — dual writers on one DNS record

Two roots that both hold **the same DNS record** in state (one created it,
one imported it — an innocent-looking onboarding step) will each rewrite the
record's content to their own truth on every apply. Neither errors, ever.
From each root's point of view the OTHER team is "drifting" the record —
permanent, unattributable-looking drift, healed and re-broken twice a day by
two green pipelines.

- `root-a/` creates `lab-dual.lab.<zone>` TXT = "owned-by-A"
- `root-b/` **imports** that same record and wants TXT = "owned-by-B"

Run: `scripts/demo-32-dual.sh` — applies A, imports+applies B, replans A to
show the "drift", applies A to flip it back.

**Fix:** a record has ONE owner root. Cross-team needs go through that
owner's interface (module variables / PRs), the same medicine as Topics 9/10.
Detection: Topic 27's drift job — the audit log shows *the other pipeline's
token* as the actor, which is how you catch dual writers in the wild.

**Reset:** the script destroys the record from A (B's state is local to the
demo folder and discarded with `rm -rf .terraform terraform.tfstate*`).
