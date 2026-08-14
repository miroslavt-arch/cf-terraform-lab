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

resource "cloudflare_list" "per_item" {
  account_id  = var.account_id
  name        = "lab_scale_per_item"
  kind        = "ip"
  description = "lab: sharp-edge demo — 1 list, N separate item resources"
}

# 500 separate resources. 500 refresh calls. 500 state entries. The plan
# time you are about to measure IS the lesson.
resource "cloudflare_list_item" "ip" {
  count = var.item_count

  account_id = var.account_id
  list_id    = cloudflare_list.per_item.id
  ip         = "10.${floor(count.index / 256)}.${count.index % 256}.1"
  comment    = "lab item ${count.index}"
}
