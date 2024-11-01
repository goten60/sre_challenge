# Globales

variable "aws_region" {
  description = "Region AWS"
  type = string
  default = "us-east-1"
}

variable "aws_environment" {
  description = "Ambiente"
  type = string
  default = "dev"
}

variable "aws_profile" {
  description = "Profile AWS"
  type = string
  default = "crowdar"
}

#S3
variable "s3_bucket_name" {
  description = "Nombre Bucket S3"
  type = string
  default = "s3-challenge-"
}

variable "s3_log_bucket_name" {
  description = "Nombre Bucket S3 de logs"
  type = string
  default = "s3-challenge-log-"
}

#VPC

variable "ip_ssh" {
  description = "ip para usar para ssh"
  type = string
  default = "190.44.41.44/32"
}

variable "ec2_log_group" {
  description = "Log Group EC2"
  type = string
  default = "ec2-challenge"
}

# VPC Name
variable "vpc_name" {
  description = "VPC Name"
  type = string
  default = "vpc-challenge"
}

# VPC CIDR Block
variable "vpc_cidr_block" {
  description = "VPC CIDR Block"
  type = string
  default = "10.0.0.0/16"
}

# VPC Availability Zones
variable "vpc_availability_zones" {
  description = "VPC Availability Zones"
  type = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# VPC Public Subnets
variable "vpc_public_subnets" {
  description = "VPC Public Subnets"
  type = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# VPC Private Subnets
variable "vpc_private_subnets" {
  description = "VPC Private Subnets"
  type = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

# VPC Enable NAT Gateway (True or False)
variable "vpc_enable_nat_gateway" {
  description = "Enable NAT Gateways for Private Subnets Outbound Communication"
  type = bool
  default = true
}

# VPC Single NAT Gateway (True or False)
variable "vpc_single_nat_gateway" {
  description = "Enable only single NAT Gateway in one Availability Zone to save costs during our demos"
  type = bool
  default = true
}

variable "db_identifier" {
  description = "Database Identifier"
  type = string
  default = "challenge-db"
}

variable "db_name" {
  description = "Database name"
  type = string
  default = "challenge"
}

variable "db_user" {
  description = "Database user"
  type = string
  default = "rds_master"

}

variable "dominio" {
  description = "Dominio"
  type = string
  default = "jmarquez.cl"

}

variable "sns_email" {
  description = "Email para SNS"
  type = string
  default = "goten60@gmail.com" #reemplazar por tu correo

}