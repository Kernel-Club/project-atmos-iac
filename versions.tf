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

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.3"
    }

    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.4"
    }
  }
}
