# Destroy guard — the lab's hard safety rule as executable policy.
#
# Input: `terraform show -json plan.tfplan` output.
# Fails the plan if ANY resource being destroyed is not trivially identifiable
# as lab-owned: name starts with lab- / tftest-, lives under a .lab. FQDN, or
# its Terraform address carries the lab marker.
#
# Usage: conftest test --policy policy plan.json --namespace destroy_guard
package destroy_guard

import rego.v1

destroyed_resources contains rc if {
	some rc in input.resource_changes
	"delete" in rc.change.actions
}

# A resource is lab-owned if any identifying handle carries the lab marker.
is_lab_owned(rc) if startswith(object.get(rc.change.before, "name", ""), "lab-")

is_lab_owned(rc) if startswith(object.get(rc.change.before, "name", ""), "tftest-")

is_lab_owned(rc) if contains(object.get(rc.change.before, "name", ""), ".lab.")

is_lab_owned(rc) if contains(object.get(rc.change.before, "comment", ""), "lab:")

is_lab_owned(rc) if contains(rc.address, "lab")

deny contains msg if {
	some rc in destroyed_resources
	not is_lab_owned(rc)
	msg := sprintf(
		"PLAN BLOCKED: %s would DESTROY '%s' (%s) which does not carry the lab- prefix. The lab never destroys pre-existing resources. If this is intentional, it needs an explicit human decision, not a pipeline run.",
		[rc.address, object.get(rc.change.before, "name", "<unnamed>"), rc.type],
	)
}
