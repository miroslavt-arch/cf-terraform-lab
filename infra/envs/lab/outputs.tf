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

output "tunnel_token" {
  description = "Connector token for the current tunnel (Topic 14). Export as TUNNEL_TOKEN for docker compose."
  value       = var.enable_tunnel ? module.tunnel[0].tunnel_token : null
  sensitive   = true
}

output "tunnel_next_token" {
  description = "Connector token for the rotation-generation tunnel, once rotation_generation > 1."
  value       = var.enable_tunnel && var.rotation_generation > 1 ? module.tunnel_next[0].tunnel_token : null
  sensitive   = true
}
