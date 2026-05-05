# Monitoring module
#
# CloudWatch log groups, SNS topics and metric alarms.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# --- ALB access logs bucket ---
# ELB service principal must be able to write; bucket policy is mandatory.

resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.cluster_name}-alb-logs"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-alb-logs"
  })
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-alb-logs"
    status = "Enabled"

    filter { prefix = "" }

    expiration {
      days = var.log_retention_days
    }
  }
}

# ELB service account ID differs by region; the ELB delivery principal uses
# the regional account ID listed at https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html
# ap-southeast-1 ELB account is 114774131450.
resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ELBLogDelivery"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::114774131450:root"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      },
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs.arn
      }
    ]
  })
}

# --- CloudWatch log groups ---

resource "aws_cloudwatch_log_group" "app" {
  name              = "/eks/${var.cluster_name}/app/redemption"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# --- Alerting ---

resource "aws_sns_topic" "critical_alerts" {
  name = "${var.cluster_name}-critical-alerts"
  tags = merge(var.tags, { Severity = "critical" })
}

resource "aws_sns_topic" "warning_alerts" {
  name = "${var.cluster_name}-warning-alerts"
  tags = merge(var.tags, { Severity = "warning" })
}

# 5xx error rate > 1% for 3 consecutive minutes -> page
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.cluster_name}-high-5xx-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = 1
  alarm_description   = "5xx error rate exceeds 1% for 3 consecutive periods"

  metric_query {
    id          = "error_rate"
    expression  = "(errors / total) * 100"
    label       = "Error Rate %"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 60
      stat        = "Sum"
      dimensions = {
        # ARN suffix format: app/<name>/<id>
        # Get after first deploy: aws elbv2 describe-load-balancers \
        #   --query 'LoadBalancers[?LoadBalancerName==`redemption-prod-alb`].LoadBalancerArn' \
        #   --output text | sed 's|.*loadbalancer/||'
        LoadBalancer = "app/redemption-prod-alb/REPLACE_AFTER_DEPLOY"
      }
    }
  }

  metric_query {
    id = "total"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 60
      stat        = "Sum"
      dimensions = {
        # ARN suffix format: app/<name>/<id>
        # Get after first deploy: aws elbv2 describe-load-balancers \
        #   --query 'LoadBalancers[?LoadBalancerName==`redemption-prod-alb`].LoadBalancerArn' \
        #   --output text | sed 's|.*loadbalancer/||'
        LoadBalancer = "app/redemption-prod-alb/REPLACE_AFTER_DEPLOY"
      }
    }
  }

  alarm_actions = [aws_sns_topic.critical_alerts.arn]
  ok_actions    = [aws_sns_topic.warning_alerts.arn]
  tags          = var.tags
}

# p99 latency > 500ms for 3 minutes -> page
resource "aws_cloudwatch_metric_alarm" "high_latency" {
  alarm_name          = "${var.cluster_name}-high-p99-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  extended_statistic  = "p99"
  threshold           = 0.5
  alarm_description   = "P99 latency exceeds 500ms for 3 consecutive periods"

  dimensions = {
    # ARN suffix format: app/<name>/<id>
    # Get after first deploy: aws elbv2 describe-load-balancers \
    #   --query 'LoadBalancers[?LoadBalancerName==`redemption-prod-alb`].LoadBalancerArn' \
    #   --output text | sed 's|.*loadbalancer/||'
    LoadBalancer = "app/redemption-prod-alb/REPLACE_AFTER_DEPLOY"
  }

  alarm_actions = [aws_sns_topic.critical_alerts.arn]
  ok_actions    = [aws_sns_topic.warning_alerts.arn]
  tags          = var.tags
}

# For production: replace CloudWatch alarms with Amazon Managed Prometheus + Grafana.
# AMP gives richer dashboards and longer retention. CloudWatch is sufficient for launch
# and keeps operational complexity low while the team onboards to EKS.
