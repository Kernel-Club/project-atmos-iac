locals {
  cluster_name = "${var.project_name}-eks"
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
}

module "github_actions" {
  source = "./modules/github-actions"

  project_name = var.project_name
  cluster_name = module.eks.cluster_name
  cluster_arn  = module.eks.cluster_arn
  github_org   = var.github_org
  github_repo  = var.github_repo
  environments = var.github_environments
}

module "secrets" {
  source = "./modules/secrets"

  project_name        = var.project_name
  cluster_name        = module.eks.cluster_name
  environments        = toset([for name, env in var.github_environments : name if env.namespace != null])
  openweather_api_key = var.openweather_api_key
}

module "lb_controller" {
  source = "./modules/lb-controller"

  project_name = var.project_name
  cluster_name = module.eks.cluster_name
}
