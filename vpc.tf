
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.4.0"

  name = "${var.aws_environment}-${var.vpc_name}"
  cidr                 = var.vpc_cidr_block
  azs                  = var.vpc_availability_zones
  public_subnets  = var.vpc_public_subnets
  private_subnets = var.vpc_private_subnets

  # NAT Gateways - Outbound Communication
  enable_nat_gateway   = true
  single_nat_gateway   = true

  # VPC DNS Parameters
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Additional Tags to Subnets
  public_subnet_tags = {
    Type = "Public Subnets"
  }
  private_subnet_tags = {
    Type = "Private Subnets"
  }

  tags = local.common_tags
  vpc_tags = local.common_tags


}
