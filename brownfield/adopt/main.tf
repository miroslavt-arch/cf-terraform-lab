# Topic 29 — the adoption root. LOCAL state, fully separate from envs/lab:
# adoption is quarantined until the estate plans clean, and only then would
# you consider merging it into the real environment.
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

# --- import via for_each over the CSV the seed script wrote -----------------
# One import block, N records: the CSV is the source of truth for what the
# dashboard era left behind.
locals {
  # Empty until brownfield/seed-legacy.sh has written the CSV — so this root
  # validates before the legacy estate exists.
  legacy_records = fileexists("${path.module}/../records.csv") ? {
    for r in csvdecode(file("${path.module}/../records.csv")) : r.name => r
  } : {}
}

import {
  for_each = local.legacy_records
  to       = cloudflare_dns_record.legacy[each.key]
  id       = "${var.zone_id}/${each.value.id}"
}

# Hand-written target config for the records (normalize.py rewrites the
# generated mess into this canonical shape; the gate is a quiet plan).
resource "cloudflare_dns_record" "legacy" {
  for_each = local.legacy_records

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  content = "\"legacy record ${split("-", split(".", each.value.name)[0])[2]} — made by hand\""
  ttl     = index(keys(local.legacy_records), each.key) * 120 + 120
  proxied = false
}

# --- the ruleset is adopted the OTHER way: -----------------------------------
# `terraform plan -generate-config-out=generated_ruleset.tf` writes its config
# for us (demo-29-adopt.sh appends the import block for it). Nothing to see
# here until the demo runs — that is the point.
