variable "project_name" {
  description = "Project name, used in resource names"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version of the cluster"
  type        = string
}

variable "cluster_subnet_ids" {
  description = "Subnets for the EKS control plane network interfaces (public and private)"
  type        = list(string)
}

variable "node_subnet_ids" {
  description = "Subnets where the worker nodes run"
  type        = list(string)
}

variable "public_access_cidrs" {
  description = "IP ranges that may reach the public Kubernetes API"
  type        = list(string)
}

variable "node_instance_type" {
  description = "EC2 instance type of the worker nodes"
  type        = string
}

variable "node_capacity_type" {
  description = "ON_DEMAND (stable) or SPOT (about 70% cheaper, can be interrupted)"
  type        = string
}

variable "node_desired_size" {
  description = "How many worker nodes to start with"
  type        = number
}

variable "node_min_size" {
  description = "Smallest number of worker nodes"
  type        = number
}

variable "node_max_size" {
  description = "Largest number of worker nodes"
  type        = number
}
