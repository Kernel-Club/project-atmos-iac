# This block tells Terraform which versions it is allowed to use.
# Pinning versions makes sure the code works the same on every computer.
terraform {
  # Terraform itself must be 1.16.x (1.16.0 or newer, but not 1.17).
  # This version can lock the state file inside S3, so we do not need DynamoDB.
  required_version = "~> 1.16.0"

  required_providers {
    # A "provider" is a plugin that lets Terraform talk to a service.
    # Here we use the AWS plugin.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.69" # 6.69 or newer 6.x, but not 7.x
    }
  }
}
