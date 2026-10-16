# This block configures the AWS plugin.
# Credentials (who you are in AWS) are NOT written here.
# Terraform reads them from your terminal, for example from AWS_PROFILE.
provider "aws" {
  region = var.aws_region

  # default_tags puts these tags on every resource we create.
  # Tags help you find resources in the AWS console and see what costs money.
  default_tags {
    tags = {
      Project   = "project-atmos"
      ManagedBy = "terraform"
      Stack     = "bootstrap"
    }
  }
}
