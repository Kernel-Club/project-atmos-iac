variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Short project name, used in resource names"
  type        = string
  default     = "project-atmos"
}

variable "vpc_cidr" {
  description = "IP address range of the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use (two are needed for EKS)"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "enable_nat_gateway" {
  description = "Create a NAT Gateway for private subnets (costs about $0.06 per hour)"
  type        = bool
  default     = true
}

variable "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  type        = string
  default     = "1.36"
}

# GitHub runners have no fixed IP, so the API stays open. Access still needs AWS credentials.
variable "public_access_cidrs" {
  description = "IP ranges allowed to reach the public Kubernetes API"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_type" {
  description = "EC2 instance type of the worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_desired_size" {
  description = "Number of worker nodes to start with"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 2
}

variable "github_org" {
  description = "GitHub organization that owns the application repository"
  type        = string
  default     = "Kernel-Club"
}

variable "github_repo" {
  description = "Application repository that is allowed to deploy"
  type        = string
  default     = "project-atmos-dev"
}

variable "github_environments" {
  description = "Deploy targets: GitHub Environment name and Kubernetes namespace"
  type = map(object({
    github_environment = string
    namespace          = optional(string)
  }))
  default = {
    dev = {
      github_environment = "development"
      namespace          = "dev"
    }
    prod = {
      github_environment = "production"
      namespace          = "prod"
    }
    # namespace = null: cluster admin, only for installing the platform.
    platform = {
      github_environment = "platform"
      namespace          = null
    }
  }
}

# No default on purpose. Pipeline: secret OPENWEATHER_API_KEY. Locally: TF_VAR_openweather_api_key.
variable "openweather_api_key" {
  description = "OpenWeather API key"
  type        = string
  sensitive   = true
}
