terraform {
  required_version = ">= 1.10.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {}

variable "zone_id" { type = string }
variable "zone_name" { type = string }

# Same record, canonical form: no trailing dot, exactly the bytes the API
# stores. The diff disappears because code truth == API truth, character for
# character. (NOT ignore_changes — see the README for why that "fix" is worse
# than the itch it scratches.)
resource "cloudflare_dns_record" "noisy" {
  zone_id = var.zone_id
  name    = "lab-noise.lab.${var.zone_name}"
  type    = "CNAME"
  content = "example.com"
  ttl     = 300
  proxied = false
}
