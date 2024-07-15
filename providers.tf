terraform {
  required_version = ">= 1.10.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.89.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.18.0"
    }
  }

  backend "s3" {
    bucket         = "dblckr"
    key            = "tf/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "dblckr"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
  default_tags {
    tags = var.tags
  }
}

provider "tailscale" {
  api_key = var.tailscale.api_key
}
