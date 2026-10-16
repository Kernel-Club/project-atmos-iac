terraform {
  required_version = "~> 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.69"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}
# Which versions of Terraform and the AWS plugin this project is allowed to use.
# Same versions as bootstrap, so everything behaves the same everywhere.
# "random" is a plugin that makes random values (we use it for the MongoDB password).
