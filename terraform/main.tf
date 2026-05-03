# Main - orchestrates all modules

locals {
  name_prefix = "redemption-${var.environment}"

  common_tags = merge(var.additional_tags, {
    Project     = "the-redemption"
    Environment = var.environment
  })
}

# --- Networking ---

module "vpc" {
  source = "./modules/vpc"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  tags               = local.common_tags
}

# --- EKS Cluster + Node Groups ---

module "eks" {
  source = "./modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # Baseline (on-demand) - always running for steady traffic
  baseline_node_instance_types = var.baseline_node_instance_types
  baseline_node_desired        = var.baseline_node_desired
  baseline_node_min            = var.baseline_node_min
  baseline_node_max            = var.baseline_node_max

  tags = local.common_tags
}

# --- Security (IAM, KMS, Secrets) ---

module "security" {
  source = "./modules/security"

  cluster_name          = var.cluster_name
  environment           = var.environment
  eks_oidc_issuer       = module.eks.oidc_issuer
  eks_oidc_provider_arn = module.eks.oidc_provider_arn

  tags = local.common_tags
}

# --- Monitoring & Observability ---

module "monitoring" {
  source = "./modules/monitoring"

  cluster_name       = var.cluster_name
  log_retention_days = var.log_retention_days

  tags = local.common_tags
}
