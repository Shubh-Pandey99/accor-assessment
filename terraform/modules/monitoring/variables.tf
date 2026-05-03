variable "cluster_name" { type = string }
variable "log_retention_days" { type = number }
variable "tags" {
  type    = map(string)
  default = {}
}
