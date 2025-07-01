terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # fiksiraj se na 6.0.x seriju, isključi 6.1.0:
      version = ">= 6.0.0, < 6.1.0"
    }
  }
}

provider "aws" {
  region  = "us-west-2"
}
