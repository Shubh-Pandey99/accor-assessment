variable "cluster_name" { type = string }
variable "environment" { type = string }
variable "eks_oidc_issuer" { type = string }
variable "eks_oidc_provider_arn" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
