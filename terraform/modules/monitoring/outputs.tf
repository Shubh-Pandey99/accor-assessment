output "critical_alerts_topic_arn" {
  value = aws_sns_topic.critical_alerts.arn
}

output "warning_alerts_topic_arn" {
  value = aws_sns_topic.warning_alerts.arn
}

output "alb_logs_bucket_name" {
  description = "S3 bucket name for ALB access logs — use in Ingress annotation alb.ingress.kubernetes.io/load-balancer-attributes"
  value       = aws_s3_bucket.alb_logs.bucket
}
