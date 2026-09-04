# ─────────────────────────────────────────────────────────────────────────────
# DESTROY GUARD — the single highest-value policy in this kit.
#
# WHAT IT DOES
#   Reads the JSON of a Terraform plan and REFUSES the plan if it would destroy
#   anything that is not explicitly marked as disposable.
#
# WHY IT MATTERS
#   Terraform will destroy whatever you tell it to, cheerfully and quickly. The
#   common ways to get told the wrong thing are boring: a renamed resource key
#   (destroy + create), a `for_each` whose input map lost an entry, a module
#   refactor that changes addresses, a merge that drops a block.
#
#   None of those look dangerous in a diff. All of them look identical in a
#   plan: `will be destroyed`.
#
# HOW TO USE IT
#   terraform show -json plan.tfplan > plan.json
#   conftest test --policy policy --namespace destroy_guard plan.json
#
#   Exit non-zero = the pipeline stops. That is the entire mechanism.
#
# HOW TO ADAPT IT
#   Edit `disposable_prefixes` below. Everything else can stay as-is.
#
#   Start STRICT — allow nothing, see what your real plans trip, then widen
#   deliberately. Starting permissive and tightening later never happens.
# ─────────────────────────────────────────────────────────────────────────────
package destroy_guard

import rego.v1

# ── CONFIGURE ME ─────────────────────────────────────────────────────────────
# Resources whose name starts with one of these MAY be destroyed by a pipeline.
# Everything else requires a human to do it deliberately, outside CI.
disposable_prefixes := [
	"tftest-", # contract-test resources; created and destroyed by terraform test
	"ephemeral-", # short-lived preview/PR environments
]

# Resources of these TYPES may always be destroyed — things that are pure
# derivations of config and hold no state worth protecting.
# Keep this list short and boring.
disposable_types := [
	# "aws_cloudwatch_log_metric_filter",
]
# ─────────────────────────────────────────────────────────────────────────────

resource_name(rc) := object.get(rc.change.before, "name", "")

destroyed contains rc if {
	some rc in input.resource_changes
	"delete" in rc.change.actions
}

is_disposable(rc) if {
	some prefix in disposable_prefixes
	startswith(resource_name(rc), prefix)
}

is_disposable(rc) if {
	some t in disposable_types
	rc.type == t
}

# An explicit, reviewable escape hatch: tag the resource in code.
#   tags = { pipeline_may_destroy = "true" }
is_disposable(rc) if {
	object.get(rc.change.before, ["tags", "pipeline_may_destroy"], "") == "true"
}

deny contains msg if {
	some rc in destroyed
	not is_disposable(rc)
	msg := sprintf(
		"PLAN BLOCKED: %s would DESTROY '%s' (%s). Pipelines do not destroy resources that are not explicitly disposable. If this is intentional, it needs a human doing it deliberately, not a pipeline run. To allow it: add a disposable prefix, or tag the resource pipeline_may_destroy=true in code so the exception is reviewable.",
		[rc.address, resource_name(rc), rc.type],
	)
}

# ── SECOND GUARD: replacement is destruction ────────────────────────────────
# A "replace" is a destroy followed by a create, and for stateful resources the
# destroy half is just as final. Terraform renders this as
# actions: ["delete","create"] — easy to skim past in a long plan.
replaced contains rc if {
	some rc in input.resource_changes
	"delete" in rc.change.actions
	"create" in rc.change.actions
}

# ── CONFIGURE ME ─────────────────────────────────────────────────────────────
# Types where an in-place replacement means real downtime or data loss.
protected_on_replace := [
	"aws_db_instance",
	"aws_ebs_volume",
	"google_sql_database_instance",
]
# ─────────────────────────────────────────────────────────────────────────────

deny contains msg if {
	some rc in replaced
	rc.type in protected_on_replace
	msg := sprintf(
		"PLAN BLOCKED: %s would be REPLACED (destroy + create). For %s that means downtime or data loss. Replacement of this type is a migration, not a deploy.",
		[rc.address, rc.type],
	)
}
