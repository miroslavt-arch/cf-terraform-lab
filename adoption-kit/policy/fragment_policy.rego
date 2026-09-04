# ─────────────────────────────────────────────────────────────────────────────
# FRAGMENT POLICY — what each team is allowed to contribute to a shared object.
#
# THE SETUP THIS ASSUMES
#   One shared object (a WAF ruleset, an ACL, a routing table) composed from
#   one YAML fragment per team, concatenated in a fixed order. See
#   ARCHITECTURE.md pattern 5.
#
# WHY POLICY AND NOT REVIEW
#   Review catches this only if the reviewer knows that `skip` in the LAST
#   fragment skips everything ABOVE it. That is exactly the kind of knowledge
#   that lives in one person's head and leaves with them.
#
# HOW TO USE IT
#   conftest test --policy policy config/fragments/
#
# RUN IT IN PRE-COMMIT TOO. This catches things on the laptop in a second
# rather than on the PR in five minutes.
# ─────────────────────────────────────────────────────────────────────────────
package main

import rego.v1

# ── RULE 1 — no bypass actions from a non-privileged fragment ────────────────
#
# THE FAILURE THIS PREVENTS, in full, because it is not obvious:
#   The app team's load tests keep getting challenged. They ask for a narrow
#   exception and reach for `skip`. But fragments are concatenated
#   incident -> security -> app, and a `skip` matched in the app fragment
#   skips EVERY rule, including the incident rules above it.
#
#   So during an incident, when the kill-switch is armed to challenge all
#   traffic, anything matching that app rule walks straight through. Nobody
#   was careless. The mechanism was simply much wider than the request.
#
#   The right answer is almost always `log`: it gives the team the visibility
#   they actually wanted, without the hole.
deny contains msg if {
	input.team != "security" # >>> CHANGE which team may use bypass actions
	some rule in input.rules
	rule.action == "skip"
	msg := sprintf(
		"%s fragment: rule '%s' uses action 'skip'. Skip bypasses every rule that runs above this fragment, including incident rules — so an armed kill-switch would not apply to this traffic. If you need visibility, use 'log'. Bypass actions are reserved for the security fragment.",
		[input.team, rule.ref],
	)
}

# ── RULE 2 — teams stay in their lane ────────────────────────────────────────
# Path-based ownership. An app team writing rules about /admin is either
# confused or working around the security team; both are worth a conversation
# before it merges.
deny contains msg if {
	input.team == "app" # >>> CHANGE
	some rule in input.rules
	contains(rule.expression, "/admin") # >>> CHANGE protected paths
	msg := sprintf(
		"%s fragment: rule '%s' matches an /admin path. Admin-path handling belongs to the security fragment. If you need an exception here, raise it with the security team rather than encoding it in your own fragment.",
		[input.team, rule.ref],
	)
}

# ── RULE 3 — attribution is mandatory ────────────────────────────────────────
# At 3am you read a rule in the console and need to know who owns it. Stamp
# owner and review date into the RENDERED description, not just the YAML, so
# it is visible where the incident happens.
deny contains msg if {
	not input.owner
	msg := "fragment is missing 'owner' — every rule must be attributable to a team that can be paged."
}

deny contains msg if {
	not input.review_date
	msg := "fragment is missing 'review_date' — unreviewed rules rot, and a date is the cheapest way to make staleness visible."
}

# ── RULE 4 — refs must be namespaced ─────────────────────────────────────────
# Rule refs collide across teams otherwise, and a collision in a concatenated
# list is a silent overwrite rather than an error.
deny contains msg if {
	some rule in input.rules
	not startswith(rule.ref, sprintf("%s_", [input.team]))
	msg := sprintf(
		"%s fragment: rule ref '%s' is not namespaced. Refs must start with '%s_' so they cannot collide with another team's rule.",
		[input.team, rule.ref, input.team],
	)
}
