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

# THE BUG IS THE TRAILING DOT.
# DNS people write FQDNs fully-qualified — "example.com." — and it is correct
# in every zone file on earth. Cloudflare's API stores it WITHOUT the dot.
# So: apply succeeds, and every plan from then on proposes
#     ~ content = "example.com" -> "example.com."
# forever. Applying "fixes" nothing; the next plan says the same thing.
# VERIFIED reproducing on provider v5.23.0 (2026-08-14).
resource "cloudflare_dns_record" "noisy" {
  zone_id = var.zone_id
  name    = "lab-noise.lab.${var.zone_name}"
  type    = "CNAME"
  content = "example.com."
  ttl     = 300
  proxied = false
}
