locals {
  cluster_name = "${var.project_name}-eks"
}
# The EKS cluster name. We need it now because the subnets must be tagged with it
# so that Kubernetes knows where it may create load balancers.

module "network" {
  source = "./modules/network"

  project_name       = var.project_name
  cluster_name       = local.cluster_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  enable_nat_gateway = var.enable_nat_gateway
}
# Calls the network module (the folder modules/network) and gives it the inputs it needs.
# Later we will add more modules here: eks, iam, secrets.

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
# Calls the EKS module.
# - cluster_subnet_ids: the control plane gets network interfaces in all four subnets.
# - node_subnet_ids: nodes go to PRIVATE subnets when NAT is on (the target design).
#   If you turn NAT off to save money, nodes move to PUBLIC subnets, because
#   private nodes without NAT cannot reach the internet and would never join.

module "github_actions" {
  source = "./modules/github-actions"

  project_name = var.project_name
  cluster_name = module.eks.cluster_name
  cluster_arn  = module.eks.cluster_arn
  github_org   = var.github_org
  github_repo  = var.github_repo
  environments = var.github_environments
}
# Calls the github-actions module. It uses the cluster name from the EKS module,
# so Terraform creates the cluster first and the roles after it.

module "secrets" {
  source = "./modules/secrets"

  project_name        = var.project_name
  cluster_name        = module.eks.cluster_name
  environments        = toset([for name, env in var.github_environments : name if env.namespace != null])
  openweather_api_key = var.openweather_api_key
}
# Calls the secrets module. It creates secrets for every environment that has a
# namespace (dev and prod). "platform" has no namespace, so it gets no secrets.

module "lb_controller" {
  source = "./modules/lb-controller"

  project_name = var.project_name
  cluster_name = module.eks.cluster_name
}
# Calls the load balancer module. It only creates the AWS permissions.
# The controller program itself is installed later with Helm by the platform workflow.
