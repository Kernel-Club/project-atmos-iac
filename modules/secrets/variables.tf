variable "project_name" {
  description = "Project name, used in secret names"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environments" {
  description = "Environment names that get their own secrets (for example dev and prod)"
  type        = set(string)
}

variable "openweather_api_key" {
  description = "OpenWeather API key (real secret, never write it in Git)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.openweather_api_key) > 0
    error_message = "openweather_api_key must not be empty."
  }
}
# Inputs of the module. "sensitive" means Terraform hides the value in its output.
