# The security baseline is a locals map: ONE source of truth for zone settings.
# Exactly one root should own these — see ARCHITECTURE.md pattern 4 for what
# happens when two do.
locals {
  settings_baseline = {
    always_use_https = "on"
    min_tls_version  = "1.2"
    tls_1_3          = "on"
    browser_check    = "on"
    security_level   = "medium"
  }

  # Overrides win, but only for keys the validation let through. Zones with
  # manage_settings = false contribute NOTHING here: they consume the module
  # for records without contending for the singleton.
  zone_settings = merge([
    for zk, z in var.zones : {
      for sk, sv in merge(local.settings_baseline, z.settings_overrides) :
      "${zk}/${sk}" => { zone_id = z.zone_id, setting = sk, value = sv }
    } if z.manage_settings
  ]...)

  # Flatten zone->records into a single addressable map.
  records = merge([
    for zk, z in var.zones : {
      for rk, r in z.records :
      "${zk}/${rk}" => {
        zone_id = z.zone_id
        fqdn    = "${rk}.${z.subdomain}.${z.zone_name}"
        type    = r.type
        content = r.content
        ttl     = r.ttl
        proxied = r.proxied
        comment = coalesce(r.comment, "managed by zone-baseline (${z.metadata.owner})")
      }
    }
  ]...)
}

# for_each rather than count: the plan names precisely which setting changes,
# and removing one from the baseline becomes an explicit, reviewable destroy
# rather than a silent re-index of everything after it.
resource "cloudflare_zone_setting" "this" {
  for_each = local.zone_settings

  zone_id    = each.value.zone_id
  setting_id = each.value.setting
  value      = each.value.value
}

resource "cloudflare_dns_record" "this" {
  for_each = local.records

  zone_id = each.value.zone_id
  name    = each.value.fqdn
  type    = each.value.type
  content = each.value.content
  ttl     = each.value.ttl
  proxied = each.value.proxied
  comment = each.value.comment
}
