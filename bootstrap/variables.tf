# Variables are the inputs of our code.
# Changing a value here changes the result without editing main.tf.

variable "aws_region" {
  description = "AWS region where the state bucket will be created"
  type        = string
  default     = "ap-northeast-2" # Seoul
}

variable "project_name" {
  description = "Short project name, used in resource names"
  type        = string
  default     = "project-atmos"
}
