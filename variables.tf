variable "aws_region" {}
variable "aws_profile" {}
data "aws_availability_zones" "available" {}
variable "vpc_cidr" {}

variable "cidrs" {
  type = "map"
}

variable "localip" {}
variable "cloudip" {}
variable "domain_name" {}
variable "db_instance_class" {}
variable "db_name" {}
variable "db_user" {}
variable "db_password" {}
