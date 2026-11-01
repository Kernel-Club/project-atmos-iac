locals {
  cluster_name = "${var.project_name}-eks"
  namespaces   = toset([for env in var.github_environments : env.namespace])
}

# Created in bootstrap/. It runs terraform plan, so it must be able to read the cluster.
data "aws_iam_role" "plan" {
  name = "${var.project_name}-iac-plan"
}

module "network" {
  source = "./modules/network"

  project_name       = var.project_name
  cluster_name       = local.cluster_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  enable_nat_gateway = var.enable_nat_gateway
}

module "eks" {
  source = "./modules/eks"

  project_name        = var.project_name
  cluster_name        = local.cluster_name
  cluster_version     = var.cluster_version
  cluster_subnet_ids  = concat(module.network.private_subnet_ids, module.network.public_subnet_ids)
  node_subnet_ids     = var.enable_nat_gateway ? module.network.private_subnet_ids : module.network.public_subnet_ids
  public_access_cidrs = var.public_access_cidrs
  node_instance_type  = var.node_instance_type
  node_capacity_type  = var.node_capacity_type
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size

  admin_principal_arns  = var.cluster_admin_arns
  viewer_principal_arns = [data.aws_iam_role.plan.arn]
}

module "github_actions" {
  source = "./modules/github-actions"

  project_name   = var.project_name
  cluster_name   = module.eks.cluster_name
  cluster_arn    = module.eks.cluster_arn
  github_org     = var.github_org
  github_repo    = var.github_repo
  github_org_id  = var.github_org_id
  github_repo_id = var.github_repo_id
  environments   = var.github_environments
}

module "secrets" {
  source = "./modules/secrets"

  project_name        = var.project_name
  cluster_name        = module.eks.cluster_name
  environments        = toset(keys(var.github_environments))
  openweather_api_key = var.openweather_api_key
}

module "lb_controller" {
  source = "./modules/lb-controller"

  project_name = var.project_name
  cluster_name = module.eks.cluster_name
}

# Everything the Helm chart in project-atmos-k8s expects from the cluster:
# namespaces, StorageClass, Gateway API, Load Balancer Controller, External Secrets, RBAC for the deploy roles.
module "platform" {
  source = "./modules/platform"

  cluster_name   = module.eks.ready_cluster_name
  region         = var.aws_region
  vpc_id         = module.network.vpc_id
  namespaces     = local.namespaces
  deployer_group = module.github_actions.deployer_group

  lb_controller_service_account    = module.lb_controller.service_account
  external_secrets_service_account = module.secrets.external_secrets_service_account

  lb_controller_version    = var.lb_controller_version
  external_secrets_version = var.external_secrets_version
}
