# Topic 10 — WAF ruleset composition from per-team YAML fragments.
#
# Ordering is deterministic BY CONSTRUCTION: concat(incident, security, app).
# Nobody's YAML edit can reorder another team's rules; CODEOWNERS routes each
# fragment to its owning team; conftest lints each fragment against policy
# before it can merge.

locals {
  fragments = {
    incident = yamldecode(file("${path.module}/rules/incident.yaml"))
    security = yamldecode(file("${path.module}/rules/security.yaml"))
    app      = yamldecode(file("${path.module}/rules/app-team.yaml"))
  }

  # Topic 11 — numeric ranking makes "is this rule armed at this mode?" a
  # single comparison instead of scattered conditionals.
  mode_rank = { none = 0, elevated = 1, lockdown = 2 }

  # Owner + review date are stamped into every description by construction —
  # a rule literally cannot exist in this ruleset without attribution.
  render = { for fk, f in local.fragments :
    fk => [for r in f.rules : {
      ref         = r.ref
      description = "[owner:${f.owner}|review:${f.review_date}] ${r.description}"
      expression  = replace(r.expression, "__LAB_HOST__", var.lab_host)
      action      = r.action
      enabled = (
        # incident rules arm by mode; everyone else's rules are always on
        # unless the fragment explicitly disables them.
        try(r.min_mode, null) != null
        ? local.mode_rank[var.incident_mode] >= local.mode_rank[r.min_mode]
        : try(r.enabled, true)
      )
    }]
  }

  # incident -> security -> app. This line IS the ordering guarantee.
  ordered_rules = concat(local.render.incident, local.render.security, local.render.app)
}

resource "cloudflare_ruleset" "composed" {
  zone_id     = var.zone_id
  name        = "lab-waf-composed"
  description = "lab: composed from per-team fragments (incident/security/app) — managed by Terraform, do not edit in dashboard"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules = [for r in local.ordered_rules : {
    ref         = r.ref
    description = r.description
    expression  = r.expression
    action      = r.action
    enabled     = r.enabled
  }]
}
