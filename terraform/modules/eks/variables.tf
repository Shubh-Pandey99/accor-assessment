variable "cluster_name" { type = string }
variable "cluster_version" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }

variable "baseline_node_instance_types" { type = list(string) }
variable "baseline_node_desired" { type = number }
variable "baseline_node_min" { type = number }
variable "baseline_node_max" { type = number }

variable "eks_public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the EKS public API endpoint. Set to corporate/VPN CIDR in production; private-only endpoint is the end-state target."
  default     = []

  validation {
    condition     = length(var.eks_public_access_cidrs) == 0 || alltrue([for cidr in var.eks_public_access_cidrs : !contains(["YOUR_VPN_CIDR/32", "203.0.113.0/32"], cidr)])
    error_message = "Replace placeholder CIDRs with your corporate/VPN CIDR in terraform.tfvars before applying."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "alb_deployed" {
  type        = bool
  description = "Set to true after K8s manifests are applied and the ALB is provisioned. Terraform will look up the ALB by name and create CloudWatch alarms automatically."
  default     = false
}

variable "alert_email" {
  type        = string
  description = "Email address for SNS alert subscriptions."
}
