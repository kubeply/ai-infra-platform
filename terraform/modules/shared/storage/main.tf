# Authentication: set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables.
# For Hetzner Object Storage, these are your Hetzner Object Storage access key and secret.
# The AWS provider reads them automatically — no credentials in tfvars.
#
# This module uses the AWS provider pointed at a custom S3-compatible endpoint.
# By default it targets Hetzner Object Storage (Falkenstein). The region must
# match the location encoded in the endpoint URL.
# Set var.endpoint to target a different region or provider.

provider "aws" {
  region = var.region

  endpoints {
    s3 = var.endpoint
  }

  # Hetzner Object Storage does not expose the standard AWS validation endpoints.
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true

  # Required for S3-compatible endpoints — use path-style URLs.
  s3_use_path_style = true
}

resource "aws_s3_bucket" "storage" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "storage" {
  bucket = aws_s3_bucket.storage.id

  versioning_configuration {
    status = "Enabled"
  }
}
