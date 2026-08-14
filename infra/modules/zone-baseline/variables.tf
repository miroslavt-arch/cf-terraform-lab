# Topic 7 — thin, typed interface. One variable carries the whole contract:
# a map of zones, each with optional nested structure and defaults, so the
# call site stays small and every default is visible here, in one place.

variable "zones" {
  description = <<-EOT
    Map of zones this module manages. Key = short zone alias (used in outputs).
    Every DNS record created lives under `<subdomain>.<zone_name>` and its key
    must carry the `lab-` prefix — this is the lab's safety contract.
  EOT

  type = map(object({
    zone_id   = string
    zone_name = string
    subdomain = optional(string, "lab")

    # Records keyed by their lab-prefixed leaf name, e.g. "lab-app".
    records = optional(map(object({
      type    = string
      content = string
      ttl     = optional(number, 1) # 1 = automatic
      proxied = optional(bool, false)
      comment = optional(string)
    })), {})

    # Topic 9 — the override door: only keys on the allow-list may appear.
    settings_overrides = optional(map(string), {})

    # Nested optional object with {} default (Topic 7 requirement): callers
    # can omit it entirely and still get well-defined metadata.
    metadata = optional(object({
      owner       = optional(string, "platform-team")
      cost_center = optional(string, "lab")
    }), {})
  }))

  # Validation 1 — the lab- prefix contract on record keys.
  validation {
    condition = alltrue([
      for zk, z in var.zones : alltrue([
        for rk, r in z.records : startswith(rk, "lab-")
      ])
    ])
    error_message = "Every DNS record key must start with 'lab-'. This module refuses to create records that are not trivially identifiable as lab-owned (safety rule: build only, never collide with pre-existing names)."
  }

  # Validation 2 — record types are a closed set.
  validation {
    condition = alltrue([
      for zk, z in var.zones : alltrue([
        for rk, r in z.records : contains(["A", "AAAA", "CNAME", "TXT", "MX"], r.type)
      ])
    ])
    error_message = "Record type must be one of A, AAAA, CNAME, TXT, MX. Anything more exotic (SRV, CAA, ...) is deliberately outside this module's thin interface — add it to the interface, don't smuggle it through."
  }

  # Validation 3 — TTL is either automatic (1) or a sane explicit value.
  validation {
    condition = alltrue([
      for zk, z in var.zones : alltrue([
        for rk, r in z.records : r.ttl == 1 || (r.ttl >= 60 && r.ttl <= 86400)
      ])
    ])
    error_message = "ttl must be 1 (automatic) or between 60 and 86400 seconds. Values below 60 are rejected by the Cloudflare API; catching it here fails the plan instead of the apply."
  }

  # Validation 4 (Topic 9) — the allow-listed override door. The baseline is a
  # singleton owned by this module; only these settings may be overridden.
  validation {
    condition = alltrue([
      for zk, z in var.zones : alltrue([
        for sk, sv in z.settings_overrides :
        contains(["security_level", "browser_check", "challenge_ttl"], sk)
      ])
    ])
    error_message = "settings_overrides only accepts: security_level, browser_check, challenge_ttl. All other zone settings are owned by the baseline in this module — override requests for them belong in a PR against the baseline, not in a call-site override."
  }
}
