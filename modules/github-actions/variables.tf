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
  description = "Application repository that is allowed to deploy"
  type        = string
}

variable "environments" {
  description = "One entry per deploy target: the GitHub Environment name and the Kubernetes namespace it may change (null = whole cluster)"
  type = map(object({
    github_environment = string
    namespace          = optional(string)
  }))
}
