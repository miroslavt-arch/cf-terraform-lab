variable "zone_id" {
  description = "Zone id in your TEST account. Never a production zone."
  type        = string
}

variable "zone_name" {
  description = "Zone name, e.g. sandbox.example.com"
  type        = string
}

variable "resource_prefix" {
  description = "Prefix for everything this root creates. Must match policy/destroy_guard.rego."
  type        = string
  default     = "tf-"
}

variable "subdomain" {
  description = "All records live under <subdomain>.<zone_name>, so this root can never collide with anything at the apex."
  type        = string
  default     = "sandbox"
}

variable "manage_settings" {
  description = <<-EOT
    Whether THIS root owns the zone's singleton settings.

    Exactly one root in your estate may set this true for a given zone. If two
    do, both applies succeed and each silently reverts the other, forever, with
    both pipelines green. See ARCHITECTURE.md pattern 4.

    Set false when pointing this sandbox at a zone another root already owns.
  EOT
  type        = bool
  default     = true
}
