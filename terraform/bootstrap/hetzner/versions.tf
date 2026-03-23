terraform {
  required_version = ">= 1.5"

  # Intentionally local — this config creates the remote state bucket,
  # so it cannot itself use remote state.
  backend "local" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
