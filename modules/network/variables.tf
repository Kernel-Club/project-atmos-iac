variable "project_name" {
  description = "Project name, used in resource names"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name, used in subnet tags"
  type        = string
}

variable "vpc_cidr" {
  description = "IP address range of the VPC"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones to create subnets in"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Create a NAT Gateway for the private subnets"
  type        = bool
}
# Inputs of the network module. The values come from main.tf in the project root.
