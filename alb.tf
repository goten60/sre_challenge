# Security Group for Public Load Balancer
module "loadbalancer_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  #version = "3.18.0"
  version = "5.1.0"

  name = "loadbalancer-sg"
  description = "Security Group with HTTP open for entire Internet (IPv4 CIDR), egress ports are all world open"
  vpc_id = module.vpc.vpc_id
  # Ingress Rules & CIDR Blocks
  ingress_rules = ["http-80-tcp","https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  # Egress Rule - all-all open
  egress_rules = ["all-all"]
  tags = local.common_tags


}

# Terraform AWS Application Load Balancer (ALB)
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  #version = "5.16.0"
  version = "9.4.0"

  name = "challenge-alb"
  internal           = false
  load_balancer_type = "application"
  vpc_id = module.vpc.vpc_id
  subnets = module.vpc.public_subnets
  #security_groups = [module.loadbalancer_sg.this_security_group_id]
  security_groups = [module.loadbalancer_sg.security_group_id]
  idle_timeout        = 60
  drop_invalid_header_fields = true
  enable_cross_zone_load_balancing = false


  # For example only
  enable_deletion_protection = false

  /* access_logs = {
    bucket = s3_bucket_name
    prefix = "alb-access-logs"
  } */
# Listeners
  listeners = {
/*
    my-http-listener = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "mytg1"
      }
    }
 */
    ex-http-https-redirect = {
      port     = 80
      protocol = "HTTP"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
    ex-https = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = aws_acm_certificate.my_certificate.arn

      forward = {
        target_group_key = "mytg1"
      }
    }

  }

# Target Groups
  target_groups = {
   # Target Group-1: mytg1
   mytg1 = {
      # VERY IMPORTANT: We will create aws_lb_target_group_attachment resource separately when we use create_attachment = false, refer above GitHub issue URL.
      ## Github ISSUE: https://github.com/terraform-aws-modules/terraform-aws-alb/issues/316
      ## Search for "create_attachment" to jump to that Github issue solution
      create_attachment = false
      name_prefix                       = "mytg1-"
      protocol                          = "HTTP"
      port                              = 80
      target_type                       = "instance"
      #target_id = aws_instance.web.id
      deregistration_delay              = 10
      load_balancing_cross_zone_enabled = false
      protocol_version = "HTTP1"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-399"
      }# End of health_check Block
      tags = local.common_tags # Target Group Tags
    } # END of Target Group: mytg1
  } # END OF target_groups Block
  tags = local.common_tags # ALB Tags
}

# Load Balancer Target Group Attachment
resource "aws_lb_target_group_attachment" "mytg1" {
  target_group_arn = module.alb.target_groups["mytg1"].arn
  target_id        = aws_instance.web.id
  port             = 80
}


resource "aws_vpc_security_group_ingress_rule" "allow_alb" {
  security_group_id = aws_security_group.ec2_sg.id
  referenced_security_group_id = module.alb.security_group_id
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}




output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = module.alb.dns_name
}



#route53
resource "aws_route53_zone" "primary" {
  name = var.dominio
  tags = local.common_tags
}

# Crear un certificado de ACM
resource "aws_acm_certificate" "my_certificate" {
  domain_name       = var.dominio
  subject_alternative_names = ["www.${var.dominio}", "*.${var.dominio}"]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
  tags = local.common_tags
}

# Recurso para validar el certificado (asegúrate de hacerlo)
resource "aws_route53_record" "cert_validation_record" {
  zone_id = aws_route53_zone.primary.zone_id # Cambia por tu zona de DNS
  for_each = {
    for dvo in aws_acm_certificate.my_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
}

resource "aws_acm_certificate_validation" "cert_validation" {
  timeouts {
    create = "5m"
  }
  certificate_arn         = aws_acm_certificate.my_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_record : record.fqdn]
}

resource "aws_route53_record" "alias_alb" {
  zone_id = aws_route53_zone.primary.zone_id # Replace with your zone ID
  name    = var.dominio
  type    = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.zone_id
    evaluate_target_health = true
  }
}

#usar en su proeedor de dominio
output "name_servers" {
  value = aws_route53_zone.primary.name_servers
  description = "The name servers for the hosted zone"
}