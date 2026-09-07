# THE MODULE CONTRACT.
#
# One typed variable carries the whole interface, so a reader learns the
# contract from one file and every default is visible in one place.

variable "resource_prefix" {
  description = <<-EOT
    Every record this module creates must start with this prefix.

    This is not cosmetic. policy/destroy_guard.rego uses the same prefix to
    decide what a pipeline may delete, so the naming rule and the safety rule
    are the same rule.
  EOT
  type        = string
  default     = "tf-"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*-$", var.resource_prefix))
    error_message = "resource_prefix must be lowercase, start with a letter, and end with a hyphen. It becomes part of DNS names."
  }
}

variable "zones" {
  description = <<-EOT
    Zones this module manages, keyed by a short alias used in outputs.
    Records are created at `<key>.<subdomain>.<zone_name>`.

    Only ONE root in your estate may set manage_settings = true for a given
    zone. Zone settings are singletons: if two roots manage them, both applies
    succeed and each silently reverts the other.
  EOT

  type = map(object({
    zone_id   = string
    zone_name = string
    subdomain = optional(string, "sandbox")

    # Records keyed by their prefixed leaf name, e.g. "tf-app".
    records = optional(map(object({
      type    = string
      content = string
      ttl     = optional(number, 1) # 1 = automatic
      proxied = optional(bool, false)
      comment = optional(string)
    })), {})

    # The override door: only keys on the allow-list may appear.
    settings_overrides = optional(map(string), {})

    # Nested optional object defaulting to {}: adding a field here later is
    # additive, so it never breaks an existing caller.
    metadata = optional(object({
      owner       = optional(string, "platform-team")
      cost_center = optional(string, "")
    }), {})

    # Defaults to FALSE. Managing a singleton is opt-in, so the dangerous case
    # has to be typed by someone and reviewed by someone.
    manage_settings = optional(bool, false)
  }))

  # ── 1. The naming contract ────────────────────────────────────────────────
  validation {
    condition = alltrue([
      for zk, z in var.zones : alltrue([
        for rk, r in z.records : startswith(rk, var.resource_prefix)
      ])
    ])
    error_message = "Every record key must start with var.resource_prefix. This module refuses to create records that are not trivially identifiable as owned by this estate, because the destroy-guard policy uses that same prefix to decide what a pipeline may delete."
  }

  # ── 2. A closed set, with the reason ──────────────────────────────────────
  validation {
    condition = alltrue([
      for zk, z in var.zones : alltrue([
        for rk, r in z.records : contains(["A", "AAAA", "CNAME", "TXT", "MX"], r.type)
      ])
    ])
    error_message = "Record type must be one of A, AAAA, CNAME, TXT, MX. Anything more exotic (SRV, CAA, ...) is deliberately out of scope: they need extra fields this interface does not model, and silently ignoring those fields is worse than refusing."
  }

  # ── 3. Catch it here, not from the API ────────────────────────────────────
  validation {
    condition = alltrue([
      for zk, z in var.zones : alltrue([
        for rk, r in z.records : r.ttl == 1 || (r.ttl >= 60 && r.ttl <= 86400)
      ])
    ])
    error_message = "ttl must be 1 (automatic) or between 60 and 86400 seconds. Values below 60 are rejected by the API; catching it here fails the plan in a second instead of failing the apply after a deploy has started."
  }

  # ── 4. Allow-list, not deny-list ──────────────────────────────────────────
  # Allow-lists fail closed. A deny-list silently permits every setting you did
  # not think of when you wrote it.
  validation {
    condition = alltrue([
      for zk, z in var.zones : alltrue([
        for sk, sv in z.settings_overrides :
        contains(["security_level", "browser_check", "challenge_ttl"], sk)
      ])
    ])
    error_message = "settings_overrides only accepts: security_level, browser_check, challenge_ttl. Everything else is owned by the baseline in this module. Widening this list is a reviewable change to the module, which is the point."
  }
}
