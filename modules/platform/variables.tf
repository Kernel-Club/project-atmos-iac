variable "cluster_name" {
  description = "Name of the EKS cluster (pass the output that waits for nodes and add-ons)"
  type        = string
}

variable "region" {
  description = "AWS region of the cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC of the cluster, for the Load Balancer Controller"
  type        = string
}

variable "namespaces" {
  description = "Application namespaces to create (for example dev and prod)"
  type        = set(string)
}

variable "deployer_group" {
  description = "Kubernetes group of the deploy roles; gets rights on the chart's CRDs in each namespace"
  type        = string
}

variable "lb_controller_service_account" {
  description = "Namespace and service account of the Load Balancer Controller, as in its Pod Identity association"
  type = object({
    namespace = string
    name      = string
  })
}

variable "external_secrets_service_account" {
  description = "Namespace and service account of External Secrets Operator, as in its Pod Identity association"
  type = object({
    namespace = string
    name      = string
  })
}

variable "lb_controller_version" {
  description = "Helm chart version of the AWS Load Balancer Controller"
  type        = string
}

variable "external_secrets_version" {
  description = "Helm chart version of External Secrets Operator"
  type        = string
}
