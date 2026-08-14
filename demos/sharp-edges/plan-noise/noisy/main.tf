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
variable "zone_name" { type = string }

# The content's CASE is the bug: the API will store lowercase, this config
# insists on MixedCase, and the plan never settles.
resource "cloudflare_dns_record" "noisy" {
  zone_id = var.zone_id
  name    = "lab-noise.lab.${var.zone_name}"
  type    = "CNAME"
  content = "LAB-App.LAB.${var.zone_name}"
  ttl     = 300
  proxied = false
}
