# Used ONLY by tests/contract (tier two). Supplied from the environment:
#   export TF_VAR_contract_zone_id=...
#   export TF_VAR_contract_zone_name=...
variable "contract_zone_id" {
  type    = string
  default = ""
}

variable "contract_zone_name" {
  type    = string
  default = ""
}
