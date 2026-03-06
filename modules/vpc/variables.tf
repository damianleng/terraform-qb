variable "environment" { type = string }
variable "project" { type = string }
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "enable_nat_gateway" {
  type    = bool
  default = true
}