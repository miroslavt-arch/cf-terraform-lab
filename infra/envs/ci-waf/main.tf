# CI-only root for Topic 11 (kill-switch), used by scripts/ci-demo-11-killswitch.sh
#
# A GitHub runner has no local state for infra/envs/lab, so it cannot flip
# incident_mode the way the laptop demo does. This root imports the SAME live
# ruleset that envs/lab owns, flips the mode against it, flips it back, and
# then drops it from state with `state rm` — never `destroy`, because the
# ruleset belongs to envs/lab.
terraform {
  required_version = ">= 1.10.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {}

variable "zone_name" { type = string }
variable "ruleset_id" { type = string }
variable "incident_mode" {
  type    = string
  default = "none"
}

data "cloudflare_zone" "lab" {
  filter = { name = var.zone_name }
}

import {
  to = module.waf.cloudflare_ruleset.composed
  id = "zones/${data.cloudflare_zone.lab.id}/${var.ruleset_id}"
}

module "waf" {
  source = "../../modules/waf-composed"

  zone_id       = data.cloudflare_zone.lab.id
  lab_host      = "lab-app.lab.${var.zone_name}"
  incident_mode = var.incident_mode
}

output "armed_rules" { value = module.waf.armed_rules }
