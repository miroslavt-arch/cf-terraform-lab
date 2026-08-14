# Token comes from the CLOUDFLARE_API_TOKEN environment variable — never from
# a file in this repository. Plan-only contexts export the read-only token
# into the same variable; the provider cannot tell the difference, the token's
# permissions enforce it.
provider "cloudflare" {}
