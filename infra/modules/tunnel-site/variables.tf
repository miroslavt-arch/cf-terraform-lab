variable "account_id" {
  description = "Cloudflare account the tunnel belongs to."
  type        = string
}

variable "zone_id" {
  description = "Zone that receives the public hostname DNS record."
  type        = string
}

variable "name" {
  description = "Tunnel name. Must carry the lab- prefix (safety contract)."
  type        = string

  validation {
    condition     = startswith(var.name, "lab-")
    error_message = "Tunnel name must start with 'lab-' so it is trivially identifiable as lab-owned."
  }
}

variable "public_hostname" {
  description = "Public FQDN served through the tunnel (e.g. lab-app.lab.<zone>)."
  type        = string
}

variable "service" {
  description = "Origin service the ingress points at, as seen from the cloudflared container (e.g. http://web:80)."
  type        = string
  default     = "http://web:80"
}

variable "manage_dns" {
  description = "Whether this module creates the public hostname record. Set false when the caller owns the record — e.g. during secret rotation, where the record must cut over between two live tunnels atomically."
  type        = bool
  default     = true
}

variable "private_cidr" {
  description = "Optional private network route published through the tunnel. null = no private route."
  type        = string
  default     = null
}
