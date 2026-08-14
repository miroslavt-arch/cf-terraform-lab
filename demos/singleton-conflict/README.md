# Singleton conflict — the Topic 9 counter-example

Zone settings are **singletons**: there is exactly one `security_level` per
zone, and Cloudflare will happily let two Terraform roots both believe they
own it. Neither root errors. Each apply simply sets the value back to *its*
truth, and the value flaps forever — the quietest kind of production fight.

- `root-a/` declares `security_level = "high"`
- `root-b/` declares `security_level = "essentially_off"` *(a deliberately
  alarming-looking value on a lab zone nobody visits)*

Both use **local state inside this demo folder** (gitignored) so the flapping
never touches the real lab state in R2.

Run the show: `scripts/demo-09-singleton-flap.sh`
Reset: apply the real baseline again — `envs/lab` owns this setting;
`terraform -chdir=infra/envs/lab apply` restores `high` (the lab override).

**The fix being taught:** one owner. The baseline lives in ONE module
(`zone-baseline`), overrides go through its allow-listed door, and every other
root keeps its hands off zone settings.
