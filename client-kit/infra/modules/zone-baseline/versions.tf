terraform {
  # 1.9 for cross-variable validation (a validation block that references
  # another variable). Drop to 1.7 if you inline the prefix instead.
  required_version = ">= 1.9.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare" # >>> CHANGE to your provider
      version = "~> 5.0"
    }
  }
}
