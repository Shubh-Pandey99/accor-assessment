output "critical_alerts_topic_arn" {
  value = aws_sns_topic.critical_alerts.arn
}

output "warning_alerts_topic_arn" {
  value = aws_sns_topic.warning_alerts.arn
}
