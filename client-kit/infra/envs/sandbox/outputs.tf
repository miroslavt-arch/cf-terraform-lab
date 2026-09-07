output "record_fqdns" {
  description = "What this root created, by logical key."
  value       = module.zone_baseline.record_fqdns
}

output "settings_applied" {
  description = "Zone settings this root owns. Non-empty because manage_settings = true here."
  value       = module.zone_baseline.settings_applied
}
