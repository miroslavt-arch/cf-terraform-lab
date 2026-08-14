# The ONLY applying root. Environments are directories, not workspaces: this
# directory owns its backend key, its tfvars and its state, and nothing else.

# Read-only lookup of the pre-existing lab zone — the environment consumes the
# zone, it does not own it.
data "cloudflare_zone" "lab" {
  filter = {
    name = var.zone_name
  }
}

locals {
  zone_id  = data.cloudflare_zone.lab.id
  lab_host = "lab-app.lab.${var.zone_name}"
}

# Topics 7 & 9 — settings baseline + lab DNS records.
# NOTE (Topic 7): source will move to a git tag ref (?ref=v0.1.0) the moment
# the public repo exists — pinning by tag is part of the demo.
module "zone_baseline" {
  source = "../../modules/zone-baseline"

  zones = {
    lab = {
      zone_id   = local.zone_id
      zone_name = var.zone_name

      records = {
        "lab-hello" = {
          type    = "TXT"
          content = "\"cf-terraform-lab: managed by zone-baseline\""
          ttl     = 300
        }
      }

      # Topic 9: this key is on the allow-list; try adding one that is not
      # (e.g. always_use_https) and watch the plan fail with the custom error.
      settings_overrides = {
        security_level = "high"
      }
    }
  }
}

# Topics 10 & 11 — composed WAF + kill-switch.
module "waf" {
  source = "../../modules/waf-composed"

  zone_id       = local.zone_id
  lab_host      = local.lab_host
  incident_mode = var.incident_mode
}

# Topic 14 — tunnel + public hostname, gated so early topics apply a minimal
# estate. Enable with: enable_tunnel = true in lab.auto.tfvars.
#
# ROTATION (two-step, zero downtime):
#   The ENVIRONMENT owns the public DNS record (manage_dns = false on both
#   modules) so cutover is one in-place content update — never a destroy.
#   step 1: rotation_generation = 2   -> lab-tunnel-g2 exists in parallel
#   step 2: rotation_cutover   = true -> record points at g2; drain old
module "tunnel" {
  source = "../../modules/tunnel-site"
  count  = var.enable_tunnel ? 1 : 0

  account_id      = var.account_id
  zone_id         = local.zone_id
  name            = "lab-tunnel"
  public_hostname = local.lab_host
  service         = "http://web:80"
  manage_dns      = false
}

module "tunnel_next" {
  source = "../../modules/tunnel-site"
  count  = var.enable_tunnel && var.rotation_generation > 1 ? 1 : 0

  account_id      = var.account_id
  zone_id         = local.zone_id
  name            = "lab-tunnel-g${var.rotation_generation}"
  public_hostname = local.lab_host
  service         = "http://web:80"
  manage_dns      = false
}

resource "cloudflare_dns_record" "lab_app" {
  count = var.enable_tunnel ? 1 : 0

  zone_id = local.zone_id
  name    = local.lab_host
  type    = "CNAME"
  content = "${var.rotation_cutover && var.rotation_generation > 1 ? module.tunnel_next[0].tunnel_id : module.tunnel[0].tunnel_id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
  comment = "lab: public hostname — owned by envs/lab so tunnel rotation is an in-place cutover"
}
