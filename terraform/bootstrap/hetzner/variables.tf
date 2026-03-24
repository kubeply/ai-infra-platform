variable "bucket_name" {
  type        = string
  default     = "terraform-state-ai-infra"
  description = "Name of the Terraform state bucket to create. Must be globally unique within Hetzner Object Storage."
}

variable "region" {
  type        = string
  default     = "fsn1"
  description = "Hetzner Object Storage location/region. Must match the endpoint location (for example fsn1, nbg1, or hel1)."
}

variable "endpoint" {
  type        = string
  default     = "https://fsn1.your-objectstorage.com"
  description = "Hetzner Object Storage S3-compatible endpoint URL."
}
