variable "bucket_name" {
  type        = string
  description = "Name of the S3-compatible object storage bucket. Must be globally unique for the chosen provider."
}

variable "region" {
  type        = string
  default     = "fsn1"
  description = "S3-compatible region/location string. For Hetzner Object Storage, this must match the endpoint location (for example fsn1, nbg1, or hel1)."
}

variable "endpoint" {
  type        = string
  default     = "https://fsn1.your-objectstorage.com"
  description = "S3-compatible endpoint URL. Defaults to Hetzner Object Storage (Falkenstein). Override for other regions or providers."
}
