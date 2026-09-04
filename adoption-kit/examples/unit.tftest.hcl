# ─────────────────────────────────────────────────────────────────────────────
# TIER-ONE UNIT TESTS — mocked provider, no credentials, no network.
#
#   terraform init -backend=false
#   terraform test
#
# Runs in about a second. That is not a nice-to-have: a suite that takes ten
# minutes gets skipped within a month, and a skipped suite is worse than none
# because you still believe it is protecting you.
# ─────────────────────────────────────────────────────────────────────────────

# THE WHOLE TRICK. The provider is stubbed, so this exercises YOUR logic with
# no API and no credential. Everything the provider would compute comes back
# as a plausible fake.
mock_provider "cloudflare" {}

# ─────────────────────────────────────────────────────────────────────────────
# 1. DEFAULTS PROPAGATE
#    optional() defaults are part of your contract. If someone changes a
#    default, that is a breaking change for every caller who relied on it.
# ─────────────────────────────────────────────────────────────────────────────
run "default_ttl_is_applied" {
  command = plan

  variables {
    zones = {
      primary = {
        zone_id   = "0000000000000000000000000000beef"
        zone_name = "example.com"
        records = {
          "lab-no-ttl" = {
            type    = "TXT"
            content = "\"no ttl given\""
            # ttl deliberately omitted
          }
        }
      }
    }
  }

  assert {
    condition     = cloudflare_dns_record.this["primary/lab-no-ttl"].ttl == 300
    error_message = "default ttl of 300 was not applied — the optional() default changed"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. VALIDATION ACTUALLY FIRES
#    expect_failures is the important one. Without it you only ever prove that
#    VALID input works — you never prove the guard rail exists. A validation
#    block with a typo in its condition passes every "happy path" test.
# ─────────────────────────────────────────────────────────────────────────────
run "bad_record_type_is_rejected" {
  command = plan

  variables {
    zones = {
      primary = {
        zone_id   = "0000000000000000000000000000beef"
        zone_name = "example.com"
        records = {
          "lab-exotic" = {
            type    = "SRV" # not in the allowed set
            content = "\"nope\""
          }
        }
      }
    }
  }

  expect_failures = [var.zones]
}

run "non_prefixed_name_is_rejected" {
  command = plan

  variables {
    zones = {
      primary = {
        zone_id   = "0000000000000000000000000000beef"
        zone_name = "example.com"
        records = {
          "prod-api" = { # missing the required prefix
            type    = "TXT"
            content = "\"nope\""
          }
        }
      }
    }
  }

  expect_failures = [var.zones]
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. THE SINGLETON GUARD HOLDS
#    manage_settings = false must mean this module touches NO zone settings.
#    This is the assertion that stops two roots fighting over a singleton.
# ─────────────────────────────────────────────────────────────────────────────
run "manage_settings_false_touches_nothing" {
  command = plan

  variables {
    zones = {
      consumer = {
        zone_id            = "0000000000000000000000000000beef"
        zone_name          = "example.com"
        manage_settings    = false
        settings_overrides = { security_level = "high" } # even when asked
        records            = {}
      }
    }
  }

  assert {
    condition     = length(output.settings_applied) == 0
    error_message = "manage_settings=false still produced settings — the singleton guard is broken, and two roots can now revert each other silently"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. ORDERING IS GUARANTEED
#    This is the assertion no linter can replace. Every individual fragment can
#    be valid while the RELATIONSHIP between them is wrong. Ordering is a
#    behavioural contract, and behavioural contracts need tests.
#
#    Concretely: if app rules end up ahead of incident rules, an app rule can
#    match first and the incident rule never runs — the kill-switch silently
#    stops working, and nothing errors.
# ─────────────────────────────────────────────────────────────────────────────
run "fragment_ordering" {
  command = plan

  module {
    source = "./modules/waf-composed" # >>> CHANGE
  }

  variables {
    zone_id  = "0000000000000000000000000000beef"
    lab_host = "app.example.com"
  }

  assert {
    condition     = output.rule_order[0] == "ir_elevated_challenge"
    error_message = "incident fragment is not first — ordering guarantee broken"
  }

  assert {
    condition     = output.rule_order[length(output.rule_order) - 1] == "app_log_beta"
    error_message = "app fragment is not last — ordering guarantee broken"
  }
}
