variable "cluster_name" { type = string }
variable "log_retention_days" { type = number }

variable "alb_arn_suffix" {
  type        = string
  description = "ALB ARN suffix (app/<name>/<id>) for CloudWatch alarm dimensions. Get after first deploy: aws elbv2 describe-load-balancers --query 'LoadBalancers[?LoadBalancerName==`redemption-prod-alb`].LoadBalancerArn' --output text | sed 's|.*loadbalancer/||'"
  default     = "app/redemption-prod-alb/REPLACE_AFTER_DEPLOY"
}

variable "tags" {
  type    = map(string)
  default = {}
}
