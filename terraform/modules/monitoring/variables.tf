variable "cluster_name" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "log_retention_days" { type = number }
variable "vpc_id" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
