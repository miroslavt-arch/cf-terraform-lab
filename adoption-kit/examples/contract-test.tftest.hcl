# ─────────────────────────────────────────────────────────────────────────────
# TIER-TWO CONTRACT TEST — real provider, real API, real resources.
#
#   terraform init -backend=false -test-directory=tests/contract
#   terraform test -test-directory=tests/contract
#
# NOTE BOTH COMMANDS CARRY -test-directory. A plain `init` does not install
# modules referenced from a non-default test directory, and the suite then
# fails at run time with "Module not installed" — which reads like a broken
# test rather than a missing flag.
# ─────────────────────────────────────────────────────────────────────────────

# DECLARE THE VARIABLES HERE, not only in the root module.
#
# A test file that references var.X without declaring it makes Terraform parse
# the TF_VAR_X value as an HCL EXPRESSION rather than a string. A zone name
# like "example.com" then dies with:
#
#     Error: Extra characters after expression
#
# which tells you nothing at all. Terraform warns that this is deprecated and
# will become a hard error.
variable "contract_zone_id" {
  type = string
}

variable "contract_zone_name" {
  type = string
}

run "record_roundtrip" {
  command = apply # REAL apply against REAL infrastructure

  module {
    source = "./modules/zones" # >>> CHANGE
  }

  variables {
    zones = {
      contract = {
        zone_id   = var.contract_zone_id
        zone_name = var.contract_zone_name

        # Never manage singletons from a test. A contract test that flips a
        # zone setting will fight your real environment.
        manage_settings = false

        records = {
          # The `tftest-` prefix is what makes auto-destroy safe: the
          # destroy-guard policy recognises it as disposable.
          "tftest-contract" = {
            type    = "TXT"
            content = "\"contract test — auto-destroyed\""
            ttl     = 120
          }
        }
      }
    }
  }

  # Things only the REAL API can tell you:

  assert {
    condition     = cloudflare_dns_record.this["contract/tftest-contract"].id != ""
    error_message = "record did not receive an id from the real API"
  }

  assert {
    condition     = output.record_fqdns["contract/tftest-contract"] == "tftest-contract.${var.contract_zone_name}"
    error_message = "FQDN contract broken — the API composed the name differently than the module assumed"
  }

  assert {
    condition     = length(output.settings_applied) == 0
    error_message = "manage_settings=false leaked settings against the real zone"
  }
}

# terraform test DESTROYS everything it created when the run ends, in reverse
# order, whether the assertions passed or failed. That automatic teardown is
# why a reserved prefix matters: it is the only thing making automated destroy
# safe to permit.
