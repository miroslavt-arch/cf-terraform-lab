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

# Identical phase claim, different team. This apply FAILS while A's ruleset
# exists — and that error is the GOOD outcome. The bad outcome is what teams
# do next (delete A's by hand / import it), which starts the ping-pong.
resource "cloudflare_ruleset" "late_transform" {
  zone_id     = var.zone_id
  name        = "lab-phase-owner-B"
  description = "lab: sharp-edge demo — root B ALSO believes it owns this phase"
  kind        = "zone"
  phase       = "http_request_late_transform"

  rules = [{
    ref         = "lab_edge_b"
    description = "B's rewrite"
    expression  = "starts_with(http.request.uri.path, \"/lab-edge-b\")"
    action      = "rewrite"
    action_parameters = {
      uri = { path = { value = "/lab-rewritten-by-b" } }
    }
  }]
}
