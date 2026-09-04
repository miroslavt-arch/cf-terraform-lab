# ─────────────────────────────────────────────────────────────────────────────
# MODULE CONTRACT — a typed interface with your organisation's rules in it.
#
# Copy the SHAPE, not the specifics. The three things worth stealing:
#   1. one map(object) with optional() defaults, not a dozen loose variables
#   2. validation blocks carrying rules the type system cannot know
#   3. error messages that name the allowed set and say WHY
# ─────────────────────────────────────────────────────────────────────────────

variable "zones" {
  description = <<-EOT
    Zones this module manages, keyed by a short logical name.

    Only ONE root module in your estate should set manage_settings = true for
    a given zone. Zone settings are singletons: if two roots manage them, both
    applies succeed and each silently reverts the other. See ARCHITECTURE.md
    pattern 4.
  EOT

  # A single map(object) with optional() means:
  #   - callers pass what they mean, not eleven positional nulls
  #   - adding a field later does not break every existing caller
  #   - the shape is self-documenting in one place
  type = map(object({
    zone_id   = string
    zone_name = string

    # Defaults to FALSE on purpose. Managing a singleton must be opt-in, so
    # the dangerous case requires someone to type it.
    manage_settings = optional(bool, false)

    records = optional(map(object({
      type    = string
      content = string
      ttl     = optional(number, 300)
      proxied = optional(bool, false)
      comment = optional(string, "")
    })), {})

    settings_overrides = optional(map(string), {})

    # Nested object defaulting to {} — new fields here are additive forever.
    metadata = optional(object({
      owner       = optional(string, "unassigned")
      cost_centre = optional(string, "")
      review_date = optional(string, "")
    }), {})
  }))

  # ── VALIDATION 1 — naming convention ──────────────────────────────────────
  # The type system knows this is a string. Only you know it must start with
  # your prefix. This is the difference between a linter and a policy.
  validation {
    condition = alltrue([
      for z in var.zones : alltrue([
        for name, _ in z.records : startswith(name, "lab-") # >>> CHANGE prefix
      ])
    ])
    error_message = "Every record key must start with 'lab-'. This module refuses to create records that are not trivially identifiable as owned by this estate, because the destroy-guard policy uses that prefix to decide what a pipeline may delete."
  }

  # ── VALIDATION 2 — bounded set, with the reason ───────────────────────────
  validation {
    condition = alltrue([
      for z in var.zones : alltrue([
        for _, r in z.records : contains(["A", "AAAA", "CNAME", "TXT", "MX"], r.type)
      ])
    ])
    error_message = "Record type must be one of A, AAAA, CNAME, TXT, MX. Anything more exotic (SRV, CAA, ...) is deliberately out of scope for this module: they need extra fields this interface does not model, and silently ignoring those fields is worse than refusing."
  }

  # ── VALIDATION 3 — catch it here, not from the API ────────────────────────
  validation {
    condition = alltrue([
      for z in var.zones : alltrue([
        for _, r in z.records : r.ttl == 1 || (r.ttl >= 60 && r.ttl <= 86400)
      ])
    ])
    error_message = "ttl must be 1 (automatic) or between 60 and 86400 seconds. Values below 60 are rejected by the API, and finding that out mid-apply costs you a failed deploy instead of a one-second local error."
  }

  # ── VALIDATION 4 — allow-list, not deny-list ──────────────────────────────
  # Allow-lists fail closed. A deny-list silently permits every setting you
  # did not think of when you wrote it.
  validation {
    condition = alltrue([
      for z in var.zones : alltrue([
        for k, _ in z.settings_overrides :
        contains(["security_level", "browser_check", "challenge_ttl"], k)
      ])
    ])
    error_message = "settings_overrides only accepts: security_level, browser_check, challenge_ttl. Other settings are owned centrally. Widening this list is a reviewable change to this module, which is the point."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# CONSUMING THIS MODULE — pin by tag, always.
#
#   module "zones" {
#     source = "git::https://github.com/ORG/REPO.git//modules/zones?ref=v1.2.0"
#     ...
#   }
#
# A relative path or a branch ref means your environment changes whenever
# someone else pushes. A TAG means upgrading is a commit you make on purpose,
# visible in a diff, and revertible. This is the single cheapest way to stop
# environments drifting under you.
# ─────────────────────────────────────────────────────────────────────────────

# ── CONTRACT OUTPUTS ─────────────────────────────────────────────────────────
# Outputs are part of the interface. Export what callers need to assert on,
# so their tests can check behaviour rather than reaching into internals.

output "record_fqdns" {
  description = "Map of logical key -> fully-qualified name, for assertions."
  value       = { for k, r in cloudflare_dns_record.this : k => r.name }
}

output "settings_applied" {
  description = "Settings this module actually manages. Empty when manage_settings = false — assert on this to prove the singleton guard holds."
  value       = keys(cloudflare_zone_setting.this)
}
