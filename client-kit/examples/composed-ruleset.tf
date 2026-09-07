# ─────────────────────────────────────────────────────────────────────────────
# COMPOSITION FROM FRAGMENTS — several teams, one shared object, no conflicts.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  # One file per team. Merge conflicts die here: teams touch different files.
  fragments = {
    for team in ["incident", "security", "app"] :
    team => yamldecode(file("${path.module}/fragments/${team}.yaml"))
  }

  # Stamp owner + review date into the RENDERED description. At 3am you read
  # the rule in the provider's console, not in this repo — so the attribution
  # has to travel with the object.
  render = {
    for team, frag in local.fragments : team => [
      for r in frag.rules : {
        ref         = r.ref
        expression  = replace(r.expression, "__HOST__", var.host)
        action      = r.action
        description = format("[owner:%s|review:%s] %s", frag.owner, frag.review_date, r.description)

        # Emergency rules are deployed but disabled until incident_mode says
        # otherwise. See ARCHITECTURE.md pattern 6.
        enabled = startswith(r.ref, "ir_") ? local.mode_rank[var.incident_mode] >= lookup(r, "min_mode_rank", 1) : true
      }
    ]
  }

  mode_rank = { none = 0, elevated = 1, lockdown = 2 }

  # ── THE ORDERING GUARANTEE ────────────────────────────────────────────────
  # Precedence is structural, not conventional. Incident rules come first
  # because this line says so — not because three teams remembered a rule.
  #
  # Changing this order is a one-line diff that LOOKS harmless and silently
  # disables your kill-switch. That is exactly why there is a unit test
  # asserting it. See examples/unit.tftest.hcl run "fragment_ordering".
  ordered_rules = concat(
    local.render.incident,
    local.render.security,
    local.render.app,
  )
}

resource "cloudflare_ruleset" "composed" {
  zone_id = var.zone_id
  name    = "waf-composed"
  kind    = "zone"
  phase   = "http_request_firewall_custom"

  dynamic "rules" {
    for_each = local.ordered_rules
    content {
      ref         = rules.value.ref
      expression  = rules.value.expression
      action      = rules.value.action
      description = rules.value.description
      enabled     = rules.value.enabled
    }
  }
}

# Export the order so a test can assert on it without reaching into internals.
output "rule_order" {
  value = [for r in local.ordered_rules : r.ref]
}
