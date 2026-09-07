# ─────────────────────────────────────────────────────────────────────────────
# BROWNFIELD ADOPTION — bringing a hand-built estate under Terraform with no
# outage, using declarative import blocks.
#
# WHY import BLOCKS AND NOT THE `terraform import` COMMAND
#   The CLI command was a one-shot you ran by hand, in the right order, against
#   the right workspace, and hoped. It left no trace in code and could not be
#   reviewed. Import blocks are ordinary configuration: they appear in the
#   diff, get reviewed, and can be generated from a list.
# ─────────────────────────────────────────────────────────────────────────────

# STEP 1 — inventory what already exists, as data rather than as prose.
# Produce this CSV however you like: the provider's API, a `cf-terraforming`
# style tool, or an export from the console.
locals {
  legacy = {
    for row in csvdecode(file("${path.module}/legacy-records.csv")) :
    row.name => row
  }
}

# STEP 2 — one import block, for_each over the inventory.
# `to` is the address the resource WILL have; `id` is the provider's id for
# the thing that already exists.
import {
  for_each = local.legacy

  to = cloudflare_dns_record.adopted[each.key]
  id = "${var.zone_id}/${each.value.id}"
}

# STEP 3 — the resource block itself.
#
# You do not have to write this by hand. Run:
#
#   terraform plan -generate-config-out=generated.tf
#
# Terraform writes it for you: correct, complete, and unreadable. Then run it
# through scripts/normalize.py to get something a human will maintain. If you
# skip the normalise step, nobody will ever touch this file again.
resource "cloudflare_dns_record" "adopted" {
  for_each = local.legacy

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  content = each.value.content
  ttl     = tonumber(each.value.ttl)
}

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 — THE GATE. This is the step people skip.
#
# Adoption is NOT finished when the import applies. It is finished when a FRESH
# plan says "No changes". Until then you have two descriptions of one estate
# and no idea which one is true.
#
# Make it a hard gate in CI, not a habit:
#
#   terraform plan -detailed-exitcode -input=false
#   case $? in
#     0) echo "clean — adoption complete, you may now refactor" ;;
#     1) echo "plan failed"; exit 1 ;;
#     2) echo "NOT clean — config does not yet match reality. Do NOT refactor."; exit 1 ;;
#   esac
#
# Only after a clean plan should anyone rename, restructure, or modularise.
# Refactoring on top of an uncertain baseline is how adoptions cause outages.
# ─────────────────────────────────────────────────────────────────────────────
