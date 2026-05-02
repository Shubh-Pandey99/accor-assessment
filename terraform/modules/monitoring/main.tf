# Monitoring module
#
# CloudWatch log groups, SNS topics and metric alarms.
# SNS topics for alerting.

data "aws_caller_identity" "current" {}

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
        LoadBalancer = "${var.cluster_name}-alb"
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
        LoadBalancer = "${var.cluster_name}-alb"
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
    LoadBalancer = "${var.cluster_name}-alb"
  }

  alarm_actions = [aws_sns_topic.critical_alerts.arn]
  ok_actions    = [aws_sns_topic.warning_alerts.arn]
  tags          = var.tags
}

# For production: replace CloudWatch alarms with Amazon Managed Prometheus + Grafana.
# AMP gives richer dashboards and longer retention. CloudWatch is sufficient for launch
# and keeps operational complexity low while the team onboards to EKS.
