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
