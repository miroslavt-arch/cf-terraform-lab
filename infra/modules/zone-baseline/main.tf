# Topic 9 — the security baseline is a locals map: THE single source of truth
# for zone settings. Exactly one Terraform root should own zone settings;
# demos/singleton-conflict shows what happens when two roots disagree.
locals {
  settings_baseline = {
    always_use_https = "on"
    min_tls_version  = "1.2"
    tls_1_3          = "on"
    browser_check    = "on"
    security_level   = "medium"
  }

  # merge(): overrides win, but only for keys the variable validation let in.
  # Zones with manage_settings = false contribute NO settings — they consume
  # the zone without contending for the singleton (v0.2.0).
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
        comment = coalesce(r.comment, "lab: owned by zone-baseline (${z.metadata.owner})")
      }
    }
  ]...)
}

# One resource instance per setting — for_each over the merged map means the
# plan shows precisely which setting changes, and removing a setting from the
# baseline is an explicit, reviewable destroy.
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
