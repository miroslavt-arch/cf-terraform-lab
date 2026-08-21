provider "cloudflare" {}

variable "zone_name" {
  description = "The lab zone. Supplied by TF_VAR_zone_name from repo variables."
  type        = string
}

variable "demo_note" {
  description = "Text stamped into the record. Change this in a PR to produce a visible, reviewable plan diff."
  type        = string
  default     = "created by the gated pipeline"
}

data "cloudflare_zone" "lab" {
  filter = { name = var.zone_name }
}

# One record. Lab-prefixed, harmless, and created by CI so the audience can
# watch it appear in the dashboard the moment the approval lands.
resource "cloudflare_dns_record" "ci_demo" {
  zone_id = data.cloudflare_zone.lab.id
  name    = "lab-ci-demo.lab.${var.zone_name}"
  type    = "TXT"
  content = "\"${var.demo_note}\""
  ttl     = 300
  comment = "lab: created by tf-apply.yml behind the GitHub environment gate"
}

output "record_fqdn" {
  value = cloudflare_dns_record.ci_demo.name
}
