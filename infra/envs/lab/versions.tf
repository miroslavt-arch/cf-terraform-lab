terraform {
  required_version = ">= 1.10.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }

  # Partial configuration — the R2 endpoint, bucket and credentials arrive at
  # init time:  terraform init -backend-config=../../backends/lab.s3.tfbackend
  # Credentials come from AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY env vars.
  backend "s3" {}
}
