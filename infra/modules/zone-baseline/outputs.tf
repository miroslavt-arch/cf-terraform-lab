# Topic 7 — outputs are the module's CONTRACT. Consumers depend on these
# shapes; changing them is a breaking change and warrants a major tag.

output "zone_ids" {
  description = "Map of zone alias => zone id, for downstream modules that must target the same zones."
  value       = { for zk, z in var.zones : zk => z.zone_id }
}

output "record_fqdns" {
  description = "Map of '<zone alias>/<record key>' => fully-qualified record name. This is the computed truth of where every lab record lives."
  value       = { for k, r in local.records : k => r.fqdn }
}

output "settings_applied" {
  description = "Map of '<zone alias>/<setting>' => value actually applied (baseline merged with allow-listed overrides). Lets consumers assert the effective policy without knowing the merge rules."
  value       = { for k, s in local.zone_settings : k => s.value }
}
