variable "aws_region" {
  description = "AWS region where the state bucket will be created"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Short project name, used in resource names"
  type        = string
  default     = "project-atmos"
}

variable "github_org" {
  description = "GitHub organization that owns this repository"
  type        = string
  default     = "Kernel-Club"
}

variable "iac_repo" {
  description = "This repository (the one that runs the Terraform pipeline)"
  type        = string
  default     = "project-atmos-iac"
}

variable "apply_environment" {
  description = "GitHub Environment (with required reviewers) that is allowed to run terraform apply"
  type        = string
  default     = "infrastructure"
}
