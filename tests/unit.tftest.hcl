# Topic 24, tier one — pure logic tests. mock_provider means NO credentials,
# NO network, NO API: the provider returns synthetic values for anything
# computed, and everything derived from variables/locals is asserted for real.
# Run: terraform test -filter=tests/unit.tftest.hcl   (from the repo root)

mock_provider "cloudflare" {}

variables {
  zone_id = "0000000000000000000000000000dead"
}

# ---------------------------------------------------------------------------
# zone-baseline: settings map composition (Topic 9)
# ---------------------------------------------------------------------------
run "settings_composition" {
  command = plan

  module {
    source = "./infra/modules/zone-baseline"
  }

  variables {
    zones = {
      lab = {
        zone_id            = "0000000000000000000000000000dead"
        zone_name          = "example.com"
        settings_overrides = { security_level = "high" }
      }
    }
  }

  assert {
    condition     = output.settings_applied["lab/security_level"] == "high"
    error_message = "allow-listed override did not win over the baseline"
  }

  assert {
    condition     = output.settings_applied["lab/min_tls_version"] == "1.2"
    error_message = "baseline setting lost during merge — singleton ownership is broken"
  }
}

# ---------------------------------------------------------------------------
# zone-baseline: optional() defaults propagate to resources (Topic 7)
# ---------------------------------------------------------------------------
run "default_propagation" {
  command = plan

  module {
    source = "./infra/modules/zone-baseline"
  }

  variables {
    zones = {
      lab = {
        zone_id   = "0000000000000000000000000000dead"
        zone_name = "example.com"
        records = {
          "lab-x" = { type = "A", content = "192.0.2.10" }
        }
      }
    }
  }

  assert {
    condition     = cloudflare_dns_record.this["lab/lab-x"].ttl == 1
    error_message = "ttl default (1 = automatic) did not propagate"
  }

  assert {
    condition     = cloudflare_dns_record.this["lab/lab-x"].proxied == false
    error_message = "proxied default (false) did not propagate"
  }

  assert {
    condition     = output.record_fqdns["lab/lab-x"] == "lab-x.lab.example.com"
    error_message = "FQDN contract broken: expected <key>.<subdomain>.<zone_name>"
  }
}

# ---------------------------------------------------------------------------
# zone-baseline: invalid input dies at plan with OUR message (Topic 7)
# ---------------------------------------------------------------------------
run "invalid_record_type_rejected" {
  command = plan

  module {
    source = "./infra/modules/zone-baseline"
  }

  variables {
    zones = {
      lab = {
        zone_id   = "0000000000000000000000000000dead"
        zone_name = "example.com"
        records = {
          "lab-broken" = { type = "SRV", content = "whatever" }
        }
      }
    }
  }

  expect_failures = [var.zones]
}

# ---------------------------------------------------------------------------
# waf-composed: fragment ordering is incident -> security -> app (Topic 10)
# ---------------------------------------------------------------------------
run "fragment_ordering" {
  command = plan

  module {
    source = "./infra/modules/waf-composed"
  }

  variables {
    zone_id  = "0000000000000000000000000000dead"
    lab_host = "lab-app.lab.example.com"
  }

  assert {
    condition     = output.rule_order[0] == "lab_ir_elevated_challenge"
    error_message = "incident fragment is not first — ordering guarantee broken"
  }

  assert {
    condition     = output.rule_order[length(output.rule_order) - 1] == "lab_app_log_beta"
    error_message = "app fragment is not last — ordering guarantee broken"
  }
}

# ---------------------------------------------------------------------------
# waf-composed: kill-switch arming logic (Topic 11)
# ---------------------------------------------------------------------------
run "killswitch_arming" {
  command = plan

  module {
    source = "./infra/modules/waf-composed"
  }

  variables {
    zone_id       = "0000000000000000000000000000dead"
    lab_host      = "lab-app.lab.example.com"
    incident_mode = "elevated"
  }

  assert {
    condition     = contains(output.armed_rules, "lab_ir_elevated_challenge")
    error_message = "elevated mode did not arm the elevated kill-switch"
  }

  assert {
    condition     = !contains(output.armed_rules, "lab_ir_lockdown_block")
    error_message = "elevated mode wrongly armed the LOCKDOWN rule — mode ranking broken"
  }

  assert {
    condition     = contains(output.armed_rules, "lab_sec_block_admin_paths")
    error_message = "security team's always-on rule went dark when the mode changed"
  }
}
