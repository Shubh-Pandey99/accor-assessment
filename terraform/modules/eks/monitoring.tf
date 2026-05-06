# Monitoring

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

resource "aws_sns_topic" "critical_alerts" {
  name = "${var.cluster_name}-critical-alerts"
  tags = merge(var.tags, { Severity = "critical" })
}

resource "aws_sns_topic_subscription" "critical_email" {
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic" "warning_alerts" {
  name = "${var.cluster_name}-warning-alerts"
  tags = merge(var.tags, { Severity = "warning" })
}

resource "aws_sns_topic_subscription" "warning_email" {
  topic_arn = aws_sns_topic.warning_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

data "aws_lb" "redemption" {
  count = var.alb_deployed ? 1 : 0
  name  = "${var.cluster_name}-alb"
}

# High 5xx error rate alarm
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  count = var.alb_deployed ? 1 : 0

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
        LoadBalancer = data.aws_lb.redemption[0].arn_suffix
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
        LoadBalancer = data.aws_lb.redemption[0].arn_suffix
      }
    }
  }

  alarm_actions = [aws_sns_topic.critical_alerts.arn]
  ok_actions    = [aws_sns_topic.warning_alerts.arn]
  tags          = var.tags
}

# High p99 latency alarm
resource "aws_cloudwatch_metric_alarm" "high_latency" {
  count = var.alb_deployed ? 1 : 0

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
    LoadBalancer = data.aws_lb.redemption[0].arn_suffix
  }

  alarm_actions = [aws_sns_topic.critical_alerts.arn]
  ok_actions    = [aws_sns_topic.warning_alerts.arn]
  tags          = var.tags
}
