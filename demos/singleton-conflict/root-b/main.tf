# Root B — a different team, a different repo, the same singleton. B is sure
# security_level should be "essentially_off". B is also sure nobody else
# manages it. Both teams' pipelines are green. The value flaps.
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

variable "zone_id" { type = string }

resource "cloudflare_zone_setting" "security_level" {
  zone_id    = var.zone_id
  setting_id = "security_level"
  value      = "essentially_off"
}
