# Topic 24, tier two — CONTRACT tests: real provider, real zone, real API.
# Creates ONLY lab-tftest-* records, never touches settings
# (manage_settings = false — the v0.2.0 consumer pattern), and terraform test
# auto-destroys everything it created when the run ends.
#
# Run ON DEMAND only (never on PRs):
#   terraform test -test-directory=tests/contract
# Needs: CLOUDFLARE_API_TOKEN (write) + TF_VAR_contract_zone_id/_name.

# Declared HERE, not just in the root variables.tf. A test file that
# references var.X without declaring it makes Terraform parse the TF_VAR_ value
# as an EXPRESSION rather than a string — so a zone name like
# "zesty-beta.sxplab.com" fails with "Extra characters after expression".
# Terraform warns that this is deprecated and will become an error.
variable "contract_zone_id" {
  type = string
}

variable "contract_zone_name" {
  type = string
}

run "record_roundtrip" {
  command = apply

  module {
    source = "./infra/modules/zone-baseline"
  }

  variables {
    zones = {
      contract = {
        zone_id         = var.contract_zone_id
        zone_name       = var.contract_zone_name
        manage_settings = false
        records = {
          "lab-tftest-contract" = {
            type    = "TXT"
            content = "\"tier-two contract test — auto-destroyed\""
            ttl     = 120
          }
        }
      }
    }
  }

  assert {
    condition     = cloudflare_dns_record.this["contract/lab-tftest-contract"].id != ""
    error_message = "record did not receive an id from the real API"
  }

  assert {
    condition     = output.record_fqdns["contract/lab-tftest-contract"] == "lab-tftest-contract.lab.${var.contract_zone_name}"
    error_message = "FQDN contract broken against the real zone"
  }

  assert {
    condition     = length(output.settings_applied) == 0
    error_message = "manage_settings=false leaked settings — the singleton guard failed"
  }
}
