output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "eks_oidc_issuer" {
  description = "OIDC issuer URL for IRSA"
  value       = module.eks.oidc_issuer
}

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}

output "alb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller (used in Helm bootstrap)"
  value       = module.security.alb_controller_role_arn
}

output "karpenter_irsa_arn" {
  description = "IAM role ARN for the Karpenter controller (used in Karpenter Helm bootstrap)"
  value       = module.eks.karpenter_irsa_arn
}

output "node_instance_profile_name" {
  description = "EC2 instance profile name for Karpenter-launched nodes (set in EC2NodeClass instanceProfile)"
  value       = module.eks.node_instance_profile_name
}

