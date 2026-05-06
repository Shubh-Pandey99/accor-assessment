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

output "ecr_repository_url" {
  description = "ECR repository URL for the redemption-service image (used in CI/CD push step)"
  value       = module.security.ecr_repository_url
}

output "redemption_service_role_arn" {
  description = "IRSA role ARN for the redemption-service pods (annotate ServiceAccount in inject-arns.yaml)"
  value       = module.security.redemption_service_role_arn
}

output "fluent_bit_role_arn" {
  description = "IRSA role ARN for Fluent Bit pods (annotate ServiceAccount in inject-arns.yaml)"
  value       = module.security.fluent_bit_role_arn
}

output "waf_acl_arn" {
  description = "WAFv2 Web ACL ARN for the ALB Ingress annotation"
  value       = module.security.waf_acl_arn
}

output "alb_logs_bucket_name" {
  description = "S3 bucket for ALB access logs (set in Ingress load-balancer-attributes annotation)"
  value       = module.eks.alb_logs_bucket_name
}

