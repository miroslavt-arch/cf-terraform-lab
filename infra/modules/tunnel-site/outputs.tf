output "tunnel_id" {
  description = "Tunnel id (also the CNAME target: <id>.cfargotunnel.com)."
  value       = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

output "tunnel_token" {
  description = "Connector token both replicas run with. Sensitive — reaches Docker via env var only."
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.this.token
  sensitive   = true
}

output "public_hostname" {
  description = "The FQDN served through the tunnel."
  value       = var.public_hostname
}
