terraform {
  required_version = ">= 1.9.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare" # >>> CHANGE
      version = "~> 5.0"
    }
  }

  # No backend block on purpose: this sandbox root uses LOCAL state so you can
  # run it in a test account with nothing else set up.
  #
  # >>> CHANGE before using this pattern for anything real. Local state cannot
  # be shared, cannot be locked, and is lost with the machine.
  #
  #   backend "s3" { ... }
}
