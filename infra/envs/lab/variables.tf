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

variable "enable_tunnel" {
  description = "Topic 14 gate: create the lab tunnel + public hostname. Off until the tunnel demo, so earlier topics apply a smaller estate."
  type        = bool
  default     = false
}

variable "rotation_generation" {
  description = "Topic 14 rotation: bump to 2 to create the parallel tunnel (lab-tunnel-g2) alongside the current one. Step 1 of the two-step zero-downtime rotation."
  type        = number
  default     = 1
}

variable "rotation_cutover" {
  description = "Topic 14 rotation step 2: point the public hostname at the new-generation tunnel. An in-place DNS content update — atomic at the edge, zero downtime."
  type        = bool
  default     = false
}
