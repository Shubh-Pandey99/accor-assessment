# Security module
#
# IRSA role for the redemption service (least-privilege access to DynamoDB,
# SQS, KMS, Secrets Manager). WAF with rate limiting and managed rule groups.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IRSA role for the redemption service pods.
# Only gets access to redemption-* tables/queues/secrets, nothing else.
resource "aws_iam_role" "redemption_service" {
  name = "${var.cluster_name}-redemption-svc"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = var.eks_oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${replace(var.eks_oidc_issuer, "https://", "")}:sub" = "system:serviceaccount:redemption:redemption-service"
          "${replace(var.eks_oidc_issuer, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "redemption_dynamodb" {
  name = "dynamodb-access"
  role = aws_iam_role.redemption_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBTableAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
        ]
        Resource = [
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/redemption-*",
        ]
      },
      {
        Sid    = "DynamoDBStreamAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:ListStreams",
        ]
        Resource = [
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/redemption-*/stream/*",
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "redemption_sqs" {
  name = "sqs-access"
  role = aws_iam_role.redemption_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ChangeMessageVisibility",
      ]
      Resource = [
        "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:redemption-*",
      ]
    }]
  })
}

resource "aws_iam_role_policy" "redemption_secrets" {
  name = "secrets-access"
  role = aws_iam_role.redemption_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
      ]
      Resource = [
        "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:redemption/*",
      ]
    }]
  })
}

# Secrets Manager entries
resource "aws_secretsmanager_secret" "app_config" {
  name        = "redemption/app-config"
  description = "Application configuration secrets for The Redemption"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "app_config" {
  secret_id = aws_secretsmanager_secret.app_config.id

  # Placeholder — replace with real values via CI/CD or manual bootstrap before first deploy.
  secret_string = jsonencode({
    ACCOR_API_KEY      = "REPLACE_ME"
    POINTS_RATE        = "REPLACE_ME"
    FEATURE_FLAGS      = "REPLACE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "redemption/db-credentials"
  description = "Database credentials for The Redemption"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  # Placeholder — replace with real values via CI/CD or manual bootstrap before first deploy.
  secret_string = jsonencode({
    username = "REPLACE_ME"
    password = "REPLACE_ME"
    host     = "REPLACE_ME"
    port     = "5432"
    dbname   = "REPLACE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# --- WAF ---

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.cluster_name}-waf"
  description = "WAF for The Redemption service"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate limiting per IP
  rule {
    name     = "rate-limit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 5000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
    }
  }

  # OWASP top 10
  rule {
    name     = "aws-managed-common"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedCommon"
    }
  }

  rule {
    name     = "aws-managed-sqli"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedSQLi"
    }
  }

  rule {
    name     = "aws-managed-known-bad-inputs"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedBadInputs"
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "RedemptionWAF"
  }

  tags = var.tags
}

# KMS for application-level data encryption (e.g., PII fields) would be a separate key.
# Deferred — app encryption is outside the scope of this infrastructure assessment.
