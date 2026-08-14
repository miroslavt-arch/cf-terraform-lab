variable "zone_id" {
  description = "Zone the composed ruleset is deployed to."
  type        = string
}

variable "lab_host" {
  description = "The lab hostname every rule expression is scoped to (e.g. lab-app.lab.<zone>). Scoping all rules to one host keeps the demo harmless."
  type        = string
}

# Topic 11 — the kill-switch. Rules in incident.yaml declare a min_mode; they
# stay in the ruleset permanently but are only ENABLED when the current mode
# reaches their threshold. Arming is a one-line tfvars change, not a code PR.
variable "incident_mode" {
  description = "Incident posture: none (peacetime), elevated, lockdown."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "elevated", "lockdown"], var.incident_mode)
    error_message = "incident_mode must be exactly one of: none, elevated, lockdown. There is deliberately no 'custom' escape hatch — new postures are a reviewed change to this module."
  }
}
