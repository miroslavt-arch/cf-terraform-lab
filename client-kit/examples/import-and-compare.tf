# ─────────────────────────────────────────────────────────────────────────────
# IMPORT-AND-COMPARE — drift detection when the runner has no remote state.
#
# If CI cannot reach your state backend, you cannot compare against "the state
# at last apply". You can do something arguably better: import the live object
# into an EPHEMERAL state and compare it to the code as committed.
#
# Anything the plan proposes beyond the import itself is drift.
#
# This root is CI-only. It never runs `apply`, and it never owns anything.
# ─────────────────────────────────────────────────────────────────────────────

variable "zone_id" { type = string }
variable "ruleset_id" {
  type        = string
  description = "Discovered at run time by the workflow and passed in as -var."
}

# Import the live object every run. The state is thrown away with the runner.
import {
  to = module.waf.cloudflare_ruleset.composed
  id = "zones/${var.zone_id}/${var.ruleset_id}"
}

# The SAME module the real environment uses, with the SAME inputs. If the live
# object still matches the committed code, the plan is a pure no-op.
module "waf" {
  source = "../../modules/waf-composed" # >>> CHANGE

  zone_id       = var.zone_id
  host          = var.host
  incident_mode = "none" # peacetime is the baseline you compare against
}

# ─────────────────────────────────────────────────────────────────────────────
# The workflow then counts anything that is not a no-op:
#
#   terraform plan -out=drift.tfplan
#   terraform show -json drift.tfplan > drift.json
#   n=$(jq '[.resource_changes[]?
#            | select(.change.actions
#            | (index("update") or index("create") or index("delete")))]
#           | length' drift.json)
#   [ "$n" = "0" ] || exit 1
#
# NOTE: this counts `resource_changes`, not `resource_drift`. With an ephemeral
# state there is no "previous state" for Terraform to diff against, so drift
# shows up as ordinary proposed changes. If you DO have remote state, prefer
# `-refresh-only` and read `resource_drift` instead — it separates "the world
# moved" from "the code moved", which this approach cannot.
# ─────────────────────────────────────────────────────────────────────────────
