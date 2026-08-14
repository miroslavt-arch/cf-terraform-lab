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

variable "account_id" { type = string }
variable "item_count" {
  type    = number
  default = 500
}
variable "allow_destroy" {
  type    = bool
  default = false
}

# One resource, one refresh call, however many items. prevent_destroy guards
# the expensive-to-recreate object (the lab's Topic-safety requirement) —
# lifecycle meta-arguments can't reference vars, so teardown uses
# `terraform state rm` + API delete via the teardown script instead.
resource "cloudflare_list" "bulk" {
  account_id  = var.account_id
  name        = "lab_scale_bulk"
  kind        = "ip"
  description = "lab: sharp-edge demo — 1 list, items as a collection"

  items = [for i in range(var.item_count) : {
    ip      = "10.${100 + floor(i / 256)}.${i % 256}.1"
    comment = "lab item ${i}"
  }]

  lifecycle {
    prevent_destroy = true
  }
}
