variable "account_id" {
  description = "Cloudflare account id of the lab sandbox."
  type        = string
}

variable "zone_name" {
  description = "The lab zone (e.g. gracious-binary.sxplab.com). The zone must already exist; this environment never creates or deletes zones."
  type        = string
}

variable "incident_mode" {
  description = "Kill-switch posture for the WAF (Topic 11). Flip in lab.auto.tfvars via scripts/arm-killswitch.sh."
  type        = string
  default     = "none"
}
