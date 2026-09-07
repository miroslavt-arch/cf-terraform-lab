# ─────────────────────────────────────────────────────────────────────────────
# TIER ONE — mocked provider. No credentials, no network, about a second.
#
#   terraform init -backend=false
#   terraform test
#
# That second matters. A suite that takes ten minutes gets skipped within a
# month, and a skipped suite is worse than none because you still believe it
# is protecting you.
# ─────────────────────────────────────────────────────────────────────────────

mock_provider "cloudflare" {}

variables {
  zone_id   = "0000000000000000000000000000beef"
  zone_name = "sandbox.example.com"
}

# ── 1. Defaults are part of the contract ────────────────────────────────────
run "default_ttl_propagates" {
  command = plan

  module {
    source = "./infra/modules/zone-baseline"
  }

  variables {
    resource_prefix = "tf-"
    zones = {
      s = {
        zone_id   = var.zone_id
        zone_name = var.zone_name
        records = {
          "tf-no-ttl" = {
            type    = "TXT"
            content = "\"no ttl given\""
          }
        }
      }
    }
  }

  assert {
    condition     = cloudflare_dns_record.this["s/tf-no-ttl"].ttl == 1
    error_message = "default ttl (1 = automatic) was not applied; the optional() default changed"
  }
}

# ── 2. THE SINGLETON GUARD. The cheapest regression test for pattern 4. ─────
run "manage_settings_false_touches_nothing" {
  command = plan

  module {
    source = "./infra/modules/zone-baseline"
  }

  variables {
    resource_prefix = "tf-"
    zones = {
      s = {
        zone_id            = var.zone_id
        zone_name          = var.zone_name
        manage_settings    = false
        settings_overrides = { security_level = "high" } # even when asked
        records            = {}
      }
    }
  }

  assert {
    condition     = length(output.settings_applied) == 0
    error_message = "manage_settings=false still produced settings. The singleton guard is broken, and two roots can now silently revert each other."
  }
}

run "manage_settings_true_owns_the_baseline" {
  command = plan

  module {
    source = "./infra/modules/zone-baseline"
  }

  variables {
    resource_prefix = "tf-"
    zones = {
      s = {
        zone_id         = var.zone_id
        zone_name       = var.zone_name
        manage_settings = true
        records         = {}
      }
    }
  }

  assert {
    condition     = length(output.settings_applied) == 5
    error_message = "the settings baseline changed size; if that was deliberate, update this number in the same commit"
  }
}

# ── 3. VALIDATION ACTUALLY FIRES ────────────────────────────────────────────
# expect_failures is the important one. Without it you only ever prove valid
# input works, and a validation block with a typo in its condition passes
# every happy-path test you will ever write.

run "unprefixed_record_is_rejected" {
  command = plan

  module {
    source = "./infra/modules/zone-baseline"
  }

  variables {
    resource_prefix = "tf-"
    zones = {
      s = {
        zone_id   = var.zone_id
        zone_name = var.zone_name
        records = {
          "prod-api" = { # missing the prefix
            type    = "TXT"
            content = "\"nope\""
          }
        }
      }
    }
  }

  expect_failures = [var.zones]
}

run "exotic_record_type_is_rejected" {
  command = plan

  module {
    source = "./infra/modules/zone-baseline"
  }

  variables {
    resource_prefix = "tf-"
    zones = {
      s = {
        zone_id   = var.zone_id
        zone_name = var.zone_name
        records = {
          "tf-srv" = {
            type    = "SRV" # not in the allowed set
            content = "\"nope\""
          }
        }
      }
    }
  }

  expect_failures = [var.zones]
}

run "ttl_below_api_minimum_is_rejected" {
  command = plan

  module {
    source = "./infra/modules/zone-baseline"
  }

  variables {
    resource_prefix = "tf-"
    zones = {
      s = {
        zone_id   = var.zone_id
        zone_name = var.zone_name
        records = {
          "tf-fast" = {
            type    = "TXT"
            content = "\"nope\""
            ttl     = 30 # API rejects anything under 60
          }
        }
      }
    }
  }

  expect_failures = [var.zones]
}

run "unlisted_setting_override_is_rejected" {
  command = plan

  module {
    source = "./infra/modules/zone-baseline"
  }

  variables {
    resource_prefix = "tf-"
    zones = {
      s = {
        zone_id            = var.zone_id
        zone_name          = var.zone_name
        settings_overrides = { always_use_https = "off" } # not on the allow-list
        records            = {}
      }
    }
  }

  expect_failures = [var.zones]
}

# ── 4. A malformed prefix is caught too ─────────────────────────────────────
run "prefix_without_trailing_hyphen_is_rejected" {
  command = plan

  module {
    source = "./infra/modules/zone-baseline"
  }

  variables {
    resource_prefix = "tf" # no trailing hyphen
    zones           = {}
  }

  expect_failures = [var.resource_prefix]
}
