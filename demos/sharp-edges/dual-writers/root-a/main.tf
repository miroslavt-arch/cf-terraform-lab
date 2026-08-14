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

resource "cloudflare_dns_record" "dual" {
  zone_id = var.zone_id
  name    = "lab-dual.lab.${var.zone_name}"
  type    = "TXT"
  content = "\"owned-by-A\""
  ttl     = 300
}
