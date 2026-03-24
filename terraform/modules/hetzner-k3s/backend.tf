# Hetzner Object Storage S3-compatible backend.
#
# Credentials are supplied via environment variables — never hardcode them:
#   AWS_ACCESS_KEY_ID     = value of the HZ_OBJECT_STORAGE_ACCESS_KEY secret
#   AWS_SECRET_ACCESS_KEY = value of the HZ_OBJECT_STORAGE_SECRET_KEY secret
#
# Required pre-conditions:
#   - Hetzner Object Storage bucket named "terraform-state-ai-infra" exists in fsn1.
#   - The access key has read/write permissions on that bucket.

terraform {
  backend "s3" {
    bucket = "terraform-state-ai-infra"
    key    = "hetzner-k3s/terraform.tfstate"

    # Hetzner Object Storage uses an S3-compatible API.
    endpoints = {
      s3 = "https://fsn1.your-objectstorage.com"
    }
    region = "fsn1" # Must match the Hetzner Object Storage endpoint location.

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
}
