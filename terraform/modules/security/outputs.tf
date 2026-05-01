output "redemption_service_role_arn" {
  value = aws_iam_role.redemption_service.arn
}

output "waf_acl_arn" {
  value = aws_wafv2_web_acl.main.arn
}
