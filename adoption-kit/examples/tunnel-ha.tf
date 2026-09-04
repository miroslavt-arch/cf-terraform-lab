# ─────────────────────────────────────────────────────────────────────────────
# TUNNEL HA — publish an internal service with no inbound firewall rule, and
# no single point of failure.
#
# UNVERIFIED: this pattern is documented from a working module but was not
# demonstrated end to end in our lab (the token could read tunnels, not create
# them). Test it in your own account before relying on it.
# ─────────────────────────────────────────────────────────────────────────────

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id = var.account_id
  name       = var.tunnel_name
  # Remote-managed config. A replica that restarts pulls current config from
  # the edge rather than reading a stale file baked into its image.
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id

  config = {
    ingress = concat(
      [
        for svc in var.services : {
          hostname = svc.hostname
          service  = svc.origin
        }
      ],
      # ── THE CATCH-ALL MUST BE LAST ──────────────────────────────────────
      # Omit it and the tunnel refuses to start. It is the `default:` of a
      # switch statement: every request must match something.
      [{ service = "http_status:404" }],
    )
  }
}

# DNS points at the tunnel, not at an IP. Nothing about your origin is public.
resource "cloudflare_dns_record" "tunnel" {
  for_each = { for s in var.services : s.hostname => s }

  zone_id = var.zone_id
  name    = each.key
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1 # must be automatic when proxied
}

# ─────────────────────────────────────────────────────────────────────────────
# HIGH AVAILABILITY — run TWO OR MORE connectors on ONE tunnel.
# The edge load-balances across healthy connectors. Kill one, traffic
# continues. See docker-compose.tunnel.yml.
#
# ROTATION WITHOUT DOWNTIME — two steps, never one.
#
#   WRONG: delete the old tunnel, create a new one.
#          There is a window with zero healthy connectors. That window is an
#          outage, and it is longer than you think because DNS caches.
#
#   RIGHT: 1. create tunnel B and start its connectors alongside A
#          2. move the DNS CNAME to B
#          3. drain A (wait out the DNS TTL, watch A's connection count fall)
#          4. delete A
#
#   At no point are there fewer than one healthy connector. Terraform will
#   happily do the WRONG version in a single apply if you just change the name,
#   which is why this is worth a runbook rather than a code comment.
# ─────────────────────────────────────────────────────────────────────────────
