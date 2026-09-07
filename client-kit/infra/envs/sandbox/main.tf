# ─────────────────────────────────────────────────────────────────────────────
# SANDBOX ROOT — the thing you actually run in a test account.
#
#   terraform init
#   terraform plan
#
# It creates two TXT records under a subdomain and applies the settings
# baseline. Small on purpose: enough to exercise every pattern in this kit,
# small enough to read in a minute and cheap to destroy.
# ─────────────────────────────────────────────────────────────────────────────

module "zone_baseline" {
  # Relative path so the sandbox runs from a fresh clone with no setup.
  #
  # >>> CHANGE for real use. Pin by tag so your environment cannot change
  # because somebody pushed to main:
  #   source = "git::https://github.com/ORG/REPO.git//infra/modules/zone-baseline?ref=v1.0.0"
  source = "../../modules/zone-baseline"

  resource_prefix = var.resource_prefix

  zones = {
    sandbox = {
      zone_id   = var.zone_id
      zone_name = var.zone_name
      subdomain = var.subdomain

      # THE SINGLETON DECISION, made explicitly at the root rather than
      # buried in the module. Exactly one root may say true for a given zone.
      manage_settings = var.manage_settings

      records = {
        "${var.resource_prefix}hello" = {
          type    = "TXT"
          content = "\"managed by terraform\""
          ttl     = 300
        }

        # Referenced by scripts/verify.sh, which changes its TTL and checks
        # the change reaches the API.
        "${var.resource_prefix}canary" = {
          type    = "TXT"
          content = "\"drift canary - verify.sh changes this\""
          ttl     = 300
        }
      }

      settings_overrides = {
        security_level = "medium"
      }

      metadata = {
        owner       = "platform-team" # >>> CHANGE
        cost_center = "sandbox"
      }
    }
  }
}
