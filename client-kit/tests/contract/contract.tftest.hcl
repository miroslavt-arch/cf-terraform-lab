# ─────────────────────────────────────────────────────────────────────────────
# TIER TWO — real provider, real API, real resources, auto-destroyed.
#
#   export CLOUDFLARE_API_TOKEN=...            # write, TEST account only
#   export TF_VAR_contract_zone_id=...
#   export TF_VAR_contract_zone_name=...
#   terraform init -backend=false -test-directory=tests/contract
#   terraform test -test-directory=tests/contract
#
# NOTE BOTH COMMANDS CARRY -test-directory. A plain `init` does not install
# modules referenced from a non-default test directory, and the suite then
# fails at run time with "Module not installed", which reads like a broken
# test rather than a missing flag. This cost us an hour; it need not cost you.
# ─────────────────────────────────────────────────────────────────────────────

# DECLARE THE VARIABLES HERE, not only in the root variables.tf.
#
# A test file that references var.X without declaring it makes Terraform parse
# the TF_VAR_X value as an HCL EXPRESSION rather than a string. A zone name
# like "sandbox.example.com" then dies with:
#
#     Error: Extra characters after expression
#
# which tells you nothing about the real cause. Terraform warns that this is
# deprecated and will become a hard error.
variable "contract_zone_id" {
  type = string
}

variable "contract_zone_name" {
  type = string
}

run "record_roundtrip_against_the_real_api" {
  command = apply # REAL resources, in your TEST account

  module {
    source = "./infra/modules/zone-baseline"
  }

  variables {
    # The reserved test prefix. policy/destroy_guard.rego lists this as
    # disposable, which is what makes automatic teardown safe to permit.
    resource_prefix = "tftest-"

    zones = {
      contract = {
        zone_id   = var.contract_zone_id
        zone_name = var.contract_zone_name
        subdomain = "sandbox"

        # Never manage singletons from a test. A contract test that flips a
        # zone setting will fight whatever root actually owns it.
        manage_settings = false

        records = {
          "tftest-contract" = {
            type    = "TXT"
            content = "\"contract test - auto-destroyed\""
            ttl     = 120
          }
        }
      }
    }
  }

  # Things only the REAL API can tell you:

  assert {
    condition     = cloudflare_dns_record.this["contract/tftest-contract"].id != ""
    error_message = "the record received no id from the API"
  }

  assert {
    condition     = output.record_fqdns["contract/tftest-contract"] == "tftest-contract.sandbox.${var.contract_zone_name}"
    error_message = "FQDN contract broken: the API composed the name differently than the module assumed"
  }

  assert {
    condition     = length(output.settings_applied) == 0
    error_message = "manage_settings=false leaked settings against a real zone"
  }
}

# terraform test destroys everything it created when the run ends, in reverse
# order, whether the assertions passed or failed. That automatic teardown is
# exactly why the reserved prefix matters.
