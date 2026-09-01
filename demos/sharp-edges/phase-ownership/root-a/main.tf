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

resource "cloudflare_ruleset" "managed_phase" {
  zone_id     = var.zone_id
  name        = "lab-phase-owner-A"
  description = "lab: sharp-edge demo — root A believes it owns this phase"
  kind        = "zone"
  phase       = "http_request_firewall_managed"

  rules = [{
    ref               = "lab_edge_a"
    description       = "A's managed-rules deployment"
    expression        = "http.host eq \"lab-edge-a.lab.example.com\""
    action            = "skip"
    action_parameters = { ruleset = "current" }
  }]
}
