# Define Local Values in Terraform
locals {
  environment = var.aws_environment
  common_tags = {
    environment = local.environment
    Terraform = "true"
  }
  account_id = data.aws_caller_identity.current.account_id
}