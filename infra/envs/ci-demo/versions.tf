# CI-DEMO ENVIRONMENT — Topic 20's pipeline demo.
#
# Deliberately NO backend block. This root owns exactly one record that does
# not exist yet, so an empty state is the CORRECT starting point: the PR plan
# honestly says "1 to add", and the gated apply creates it. That keeps the
# human-gate demo (reviewer + wait timer + pinned plan artifact) completely
# real without requiring a remote state backend.
#
# The applying environment for everything else is infra/envs/lab, which does
# use a backend. See docs/runbooks/topic-20.md.
terraform {
  required_version = ">= 1.10.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}
