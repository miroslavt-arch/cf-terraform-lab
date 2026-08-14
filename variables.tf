# Root-harness variables — used ONLY by tests/contract (tier two). Supplied
# via TF_VAR_contract_zone_id / TF_VAR_contract_zone_name (locally from
# ~/.cf-lab-env exports; in CI from GitHub environment variables).
variable "contract_zone_id" {
  description = "Real lab zone id for tier-two contract tests."
  type        = string
  default     = ""
}

variable "contract_zone_name" {
  description = "Real lab zone name for tier-two contract tests."
  type        = string
  default     = ""
}
