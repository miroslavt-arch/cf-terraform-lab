output "ruleset_id" {
  description = "Id of the composed ruleset."
  value       = cloudflare_ruleset.composed.id
}

output "rule_order" {
  description = "The refs in their deployed order — the contract the ordering demo asserts against."
  value       = [for r in local.ordered_rules : r.ref]
}

output "armed_rules" {
  description = "Refs of rules currently enabled, given incident_mode. Peacetime shows the kill-switch rules present but dark."
  value       = [for r in local.ordered_rules : r.ref if r.enabled]
}
