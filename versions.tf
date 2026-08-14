# Root-level provider pin. This root is a TEST HARNESS only — it holds no
# resources and no backend. `terraform test` runs from here and each run block
# sources a module under infra/modules/. The applying environment lives in
# infra/envs/lab (its own root, its own state).
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}
