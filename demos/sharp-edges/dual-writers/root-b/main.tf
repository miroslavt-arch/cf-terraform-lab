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
variable "record_id" {
  type    = string
  default = ""
}

# B "onboarded" the record by importing it. Perfectly innocent. Now two
# states hold the same object with different desired content.
import {
  for_each = var.record_id == "" ? {} : { dual = var.record_id }
  to       = cloudflare_dns_record.dual
  id       = "${var.zone_id}/${each.value}"
}

resource "cloudflare_dns_record" "dual" {
  zone_id = var.zone_id
  name    = "lab-dual.lab.${var.zone_name}"
  type    = "TXT"
  content = "\"owned-by-B\""
  ttl     = 300
}
