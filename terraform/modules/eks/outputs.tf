output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  value = aws_eks_cluster.main.certificate_authority[0].data
}

output "oidc_issuer" {
  value = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "karpenter_irsa_arn" {
  value = aws_iam_role.karpenter_controller.arn
}

output "node_instance_profile_name" {
  value = aws_iam_instance_profile.node.name
}

output "critical_alerts_topic_arn" {
  value = aws_sns_topic.critical_alerts.arn
}

output "warning_alerts_topic_arn" {
  value = aws_sns_topic.warning_alerts.arn
}

output "alb_logs_bucket_name" {
  description = "S3 bucket for ALB access logs — use in Ingress annotation alb.ingress.kubernetes.io/load-balancer-attributes"
  value       = aws_s3_bucket.alb_logs.bucket
}
