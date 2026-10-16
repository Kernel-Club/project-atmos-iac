variable "project_name" {
  description = "Project name, used in resource names"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}
# Inputs of the module. The values come from main.tf in the project root.
