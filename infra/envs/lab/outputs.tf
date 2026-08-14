output "zone_id" {
  description = "Resolved id of the lab zone."
  value       = local.zone_id
}

output "record_fqdns" {
  description = "All lab records, from the zone-baseline contract output."
  value       = module.zone_baseline.record_fqdns
}

output "waf_rule_order" {
  description = "Deployed WAF rule order (incident -> security -> app)."
  value       = module.waf.rule_order
}

output "waf_armed_rules" {
  description = "WAF rules currently enabled at the present incident_mode."
  value       = module.waf.armed_rules
}
