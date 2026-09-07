# Outputs are part of the interface. Export what callers need to ASSERT on, so
# their tests can check behaviour instead of reaching into internals.

output "record_fqdns" {
  description = "Map of logical key -> fully-qualified name."
  value       = { for k, r in cloudflare_dns_record.this : k => r.name }
}

output "record_ids" {
  description = "Map of logical key -> provider id. Empty until applied."
  value       = { for k, r in cloudflare_dns_record.this : k => r.id }
}

output "settings_applied" {
  description = <<-EOT
    Settings this module actually manages. EMPTY when manage_settings = false.

    Assert on this in a test to prove the singleton guard still holds after a
    refactor. It is the cheapest possible regression test for pattern 4.
  EOT
  value       = keys(cloudflare_zone_setting.this)
}
