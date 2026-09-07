# Root harness. Exists so `terraform test` has a root to run from; it creates
# nothing itself.
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare" # >>> CHANGE
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {}
