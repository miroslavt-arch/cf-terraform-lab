# ─────────────────────────────────────────────────────────────────────────────
# SINGLETON OWNERSHIP — the boolean that stops two pipelines fighting.
#
# A singleton is any object where exactly one exists per scope: a zone setting,
# an account-level default, a ruleset phase, a DNS record. When two Terraform
# roots declare the same singleton, BOTH APPLIES SUCCEED. Each reverts the
# other. Both pipelines stay green forever and nothing tells you.
# ─────────────────────────────────────────────────────────────────────────────

variable "manage_settings" {
  description = <<-EOT
    Whether THIS root owns the zone's singleton settings.

    Exactly one root in your entire estate may set this true for a given zone.
    Everyone else consumes this module for records only.

    Default false: the dangerous case must be opt-in, so somebody has to type
    it and somebody has to review it.
  EOT
  type        = bool
  default     = false
}

# The guard: an empty for_each means this root creates NO settings resources
# at all. Not "creates them and ignores changes" — does not create them.
resource "cloudflare_zone_setting" "this" {
  for_each = var.manage_settings ? local.settings : {}

  zone_id    = var.zone_id
  setting_id = each.key
  value      = each.value
}

# Export it so consumers can ASSERT on it. This is the line your unit test
# checks to prove the guard still holds after a refactor.
output "settings_applied" {
  description = "Settings this root manages. Empty unless manage_settings = true."
  value       = keys(cloudflare_zone_setting.this)
}

# ─────────────────────────────────────────────────────────────────────────────
# WHY NOT lifecycle { ignore_changes = [...] } ?
#
# Because it stops managing the field ENTIRELY. You would no longer see a
# genuine unauthorised change to the same setting. You'd trade a cosmetic
# annoyance for blindness on the field you were worried about.
#
# ignore_changes is right when a field is legitimately owned elsewhere and you
# never want to know. It is wrong as a way to silence a conflict you have not
# resolved.
# ─────────────────────────────────────────────────────────────────────────────
