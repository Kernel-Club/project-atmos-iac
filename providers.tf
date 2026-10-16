provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "project-atmos"
      ManagedBy = "terraform"
    }
  }
}
# Configures the AWS plugin: which region to use.
# default_tags adds the same tags to every resource, so you can find
# everything from this project in the AWS console (and check what costs money).
