# Topic 10 — per-fragment lint. Each YAML fragment is tested on its own, so
# the failure message lands on the owning team's PR, not on a merged artifact.
#
# The app-team fragment (team: app) has two hard limits:
#   1. it may never use the `skip` action (that's how a team silently
#      disables the security rules above it), and
#   2. it may never match admin paths (those belong to the security team).
#
# Usage: conftest test --policy policy infra/modules/waf-composed/rules/
package main

import rego.v1

is_app_fragment if input.team == "app"

deny contains msg if {
	is_app_fragment
	some rule in input.rules
	rule.action == "skip"
	msg := sprintf("app-team fragment: rule '%s' uses action 'skip'. Skip bypasses the incident and security rules that run above you — this action is reserved for the security fragment.", [rule.ref])
}

deny contains msg if {
	is_app_fragment
	some rule in input.rules
	contains(rule.expression, "/admin")
	msg := sprintf("app-team fragment: rule '%s' matches an /admin path. Admin-path handling belongs to the security fragment (CODEOWNERS: security team).", [rule.ref])
}

# Every fragment, any team: attribution is mandatory.
deny contains msg if {
	not input.owner
	msg := "fragment is missing 'owner' — every rule must be attributable to a team."
}

deny contains msg if {
	not input.review_date
	msg := "fragment is missing 'review_date' — unreviewed rules rot; the date makes staleness visible."
}
