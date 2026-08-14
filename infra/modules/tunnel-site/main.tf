# Topic 14 — remotely-managed tunnel: config_src = "cloudflare" means the
# ingress rules live in Cloudflare (managed by Terraform), NOT in a local
# config.yml. Replicas are stateless: run the same connector token twice and
# you have HA; kill one and the edge keeps routing through the other.

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id = var.account_id
  name       = var.name
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id

  config = {
    # ORDER MATTERS: first match wins, and the catch-all MUST be last —
    # cloudflared refuses configs whose final rule isn't service-only.
    ingress = [
      {
        hostname = var.public_hostname
        service  = var.service
      },
      {
        service = "http_status:404"
      },
    ]
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "this" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

# The public hostname is a proxied CNAME onto the tunnel's edge address.
resource "cloudflare_dns_record" "public" {
  count = var.manage_dns ? 1 : 0

  zone_id = var.zone_id
  name    = var.public_hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
  ttl     = 1
  proxied = true
  comment = "lab: tunnel ${var.name} public hostname (managed by tunnel-site)"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_route" "private" {
  count = var.private_cidr == null ? 0 : 1

  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id
  network    = var.private_cidr
  comment    = "lab: private route via ${var.name}"
}
