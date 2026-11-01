variable "project_name" {
  description = "Project name, used in resource names"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster the roles get access to"
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the EKS cluster"
  type        = string
}

variable "github_org" {
  description = "GitHub organization that owns the application repository"
  type        = string
}

variable "github_repo" {
  description = "Repository whose pipeline deploys to the cluster"
  type        = string
}

variable "github_org_id" {
  description = "Numeric ID of the GitHub organization (part of the OIDC sub claim)"
  type        = string
}

variable "github_repo_id" {
  description = "Numeric ID of the application repository (part of the OIDC sub claim)"
  type        = string
}

variable "environments" {
  description = "One entry per deploy target: the GitHub Environment name and the Kubernetes namespace it may change"
  type = map(object({
    github_environment = string
    namespace          = string
  }))
}
