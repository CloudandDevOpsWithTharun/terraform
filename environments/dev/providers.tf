provider "aws" {
  region  = var.aws_region
  profile = "default"
  default_tags {
    tags = {
      Environment = "dev"
      Project     = "eks-platform"
      ManagedBy   = "terraform"
    }
  }
}