# Authentication: set CLOUDFLARE_API_TOKEN environment variable.
# The Cloudflare provider reads it automatically — no credentials in tfvars.
#
# The zone (domain) must already exist in your Cloudflare account.
# This module does not register domains — it manages the zone configuration.

data "cloudflare_zone" "zone" {
  filter = {
    name = var.domain
  }
}
