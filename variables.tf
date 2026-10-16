variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-northeast-2"
}
# The AWS region. ap-northeast-2 is Seoul.

variable "project_name" {
  description = "Short project name, used in resource names"
  type        = string
  default     = "project-atmos"
}
# A prefix for resource names, for example "project-atmos-vpc".

variable "vpc_cidr" {
  description = "IP address range of the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
# The private IP range of our network. /16 gives us about 65,000 addresses.

variable "availability_zones" {
  description = "Availability zones to use (two are needed for EKS)"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}
# An availability zone is a separate data center in the region.
# EKS needs subnets in at least two of them.

variable "enable_nat_gateway" {
  description = "Create a NAT Gateway for private subnets (costs about $0.06 per hour)"
  type        = bool
  default     = true
}
# true  = private nodes can reach the internet through NAT (the target architecture).
# false = no NAT, saves money, but then nodes must live in public subnets.

variable "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  type        = string
  default     = "1.36"
}
# Kubernetes version. Old versions go into "extended support" which costs
# $0.60 per hour instead of $0.10, so always use a recent one.

variable "public_access_cidrs" {
  description = "IP ranges allowed to reach the public Kubernetes API"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
# 0.0.0.0/0 means "everyone". GitHub Actions has no fixed IP, so we keep it open;
# access still needs valid AWS credentials. You can put your own IP here (x.x.x.x/32).

variable "node_instance_type" {
  description = "EC2 instance type of the worker nodes"
  type        = string
  default     = "t3.medium"
}
# t3.medium = 2 vCPU, 4 GB RAM. t3.small (2 GB) is too small for MongoDB,
# Redis and monitoring in two environments, and allows only 11 pods per node.

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}
# SPOT is about 70% cheaper but AWS may stop the node with 2 minutes warning.

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
# Node count settings. Max is 2 so the bill cannot grow by surprise.

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
# Which GitHub repository may deploy to the cluster. Nobody else can use the roles.

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
    platform = {
      github_environment = "platform"
      namespace          = null
    }
  }
}
# DEV and PROD. "github_environment" must be EXACTLY the same name as the
# Environment you create in GitHub (Settings > Environments), otherwise login fails.
# "namespace" is the Kubernetes namespace this environment may change.
# "platform" has namespace = null: it may change the whole cluster and is used only to
# install the platform (load balancer controller, External Secrets, namespaces).
# You must create a GitHub Environment called "platform" and add Required reviewers.

variable "openweather_api_key" {
  description = "OpenWeather API key"
  type        = string
  sensitive   = true
}
# A real secret, so it has NO default value and is never written in a file.
# Give it from your terminal before plan/apply (fish shell):
#   set -gx TF_VAR_openweather_api_key "your-key"
