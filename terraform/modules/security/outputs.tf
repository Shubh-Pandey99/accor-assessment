output "redemption_service_role_arn" {
  value = aws_iam_role.redemption_service.arn
}

output "waf_acl_arn" {
  value = aws_wafv2_web_acl.main.arn
}

output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller.arn
}

output "fluent_bit_role_arn" {
  value = aws_iam_role.fluent_bit.arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.redemption.repository_url
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.redemption_transactions.name
}

output "sqs_queue_url" {
  value = aws_sqs_queue.redemption.url
}
