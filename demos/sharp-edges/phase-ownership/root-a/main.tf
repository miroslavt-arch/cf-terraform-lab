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

resource "cloudflare_ruleset" "late_transform" {
  zone_id     = var.zone_id
  name        = "lab-phase-owner-A"
  description = "lab: sharp-edge demo — root A believes it owns this phase"
  kind        = "zone"
  phase       = "http_request_late_transform"

  rules = [{
    ref         = "lab_edge_a"
    description = "A's rewrite"
    expression  = "starts_with(http.request.uri.path, \"/lab-edge-a\")"
    action      = "rewrite"
    action_parameters = {
      uri = { path = { value = "/lab-rewritten-by-a" } }
    }
  }]
}
