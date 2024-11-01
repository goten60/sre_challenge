#data para obtener la AMI amazon linux 2
data "aws_ami" "amzLinux" {
    most_recent = true
    owners = ["amazon"]
    filter {
        name = "name"
        values = ["amzn2-ami-hvm-*-gp2"]
    }
    filter {
        name = "root-device-type"
        values = ["ebs"]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
    filter {
        name = "architecture"
        values = ["x86_64"]
    }
}

#Security Group de EC2
resource "aws_security_group" "ec2_sg" {
  vpc_id = module.vpc.vpc_id
  name = "ec2_sg"
}

#Regla de acceso para que el EC2 pueda acceder al RDS
resource "aws_vpc_security_group_ingress_rule" "allow_rds" {
  security_group_id = aws_security_group.rds_sg.id
  referenced_security_group_id = aws_security_group.ec2_sg.id
  from_port         = 3306
  ip_protocol       = "tcp"
  to_port           = 3306
}

#Regla de acceso para que el EC2 pueda acceder a internet
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

#EC2 para el sistema wordpress
resource "aws_instance" "web" {
  ami = data.aws_ami.amzLinux.id
  instance_type = var.ec2_type
  metadata_options {
    http_tokens = "required"
  }

  subnet_id     = module.vpc.private_subnets[0] # Se pone en subnet privada ya que le trafico lo recibe el balanceador
  vpc_security_group_ids  = [aws_security_group.ec2_sg.id]
  tags = local.common_tags
  associate_public_ip_address = false
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted = true
    tags = local.common_tags
  }
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras enable php8.2
              amazon-linux-extras install php8.2 vim epel -y
              yum install -y httpd php php-mysqlnd php-cli php-pdo php-fpm php-json mariadb
              systemctl start httpd
              systemctl enable httpd
              cd /var/www/html
              curl -O https://wordpress.org/latest.tar.gz
              tar -xzvf latest.tar.gz
              #cp wordpress/wp-config-sample.php wordpress/wp-config.php
              mv wordpress/* .
              rm -rf wordpress latest.tar.gz

              #chgrp -R apache /var/www
              chmod 2775 /var/www
              find /var/www -type d -exec sudo chmod 2775 {} \;
              find /var/www -type f -exec sudo chmod 0644 {} \;
              chown -R apache:apache /var/www

              # Configurar WordPress
              #cp wp-config-sample.php wp-config.php

              #sed -i "s/database_name_here/${var.db_name}/g" wp-config.php
              #sed -i "s/username_here/${var.db_user}/g" wp-config.php
              #sed -i "s/password_here/password/g" wp-config.php
              #sed -i "s/localhost/${aws_db_instance.db_instance.endpoint}/g" wp-config.php

              # Instalar el agente de CloudWatch
              yum install -y amazon-cloudwatch-agent

              # Crear archivo de configuración para el agente
              cat <<EOT >> /opt/aws/amazon-cloudwatch-agent/bin/config.json
              {
                "metrics": {
                  "metrics_collected": {
                    "mem": {
                      "measurement": ["mem_used_percent"],
                      "metrics_collection_interval": 60
                    },
                    "disk": {
                      "measurement": ["used_percent"],
                      "metrics_collection_interval": 60,
                      "resources": ["*"]
                    }
                  },
                  "aggregation_dimensions": [
                    [
                        "InstanceId"
                    ]
                  ],
                  "append_dimensions": {
                      "InstanceId": "$${aws:InstanceId}",
                      "InstanceType": "$${aws:InstanceType}"
                  }
                },
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/var/log/httpd/access_log",
                          "log_group_name": "apache-access-logs",
                          "log_stream_name": "{instance_id}",
                          "timezone": "UTC"
                        },
                        {
                          "file_path": "/var/log/httpd/error_log",
                          "log_group_name": "apache-error-logs",
                          "log_stream_name": "{instance_id}",
                          "timezone": "UTC"
                        }
                      ]
                    }
                  }
                }
              }
              EOT

              # Iniciar el agente de CloudWatch
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json

              EOF
}

#Rol para la instancia
resource "aws_iam_role" "ssm_role" {
  name = "SSM-Access-Role"
  assume_role_policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  tags = local.common_tags
}

#Insance profile EC2
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ssm_profile"
  role = "${aws_iam_role.ssm_role.name}"
}

#Politicas necesarias para el rol
resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"

}
resource "aws_iam_role_policy_attachment" "ssm_policy_attachment2" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy_attachment" "cloudwatch_policy_attachment" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

#Alarma para el EC2 CPU
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_alarm" {
  alarm_name          = "EC2 High CPU Usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name        = "CPUUtilization"
  namespace          = "AWS/EC2"
  period             = "300"
  statistic          = "Average"
  threshold          = "80"
  alarm_description  = "This metric monitors ec2 high cpu usage"
  insufficient_data_actions = []
  dimensions = {
    InstanceId = aws_instance.web.id
  }
  alarm_actions = [aws_sns_topic.my_sns_topic.arn]
}

#Alarma para el EC2 Memoria
resource "aws_cloudwatch_metric_alarm" "high_memory_usage" {
  alarm_name          = "EC2 HighMemoryUsage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name        = "mem_used_percent"
  namespace          = "CWAgent"
  period             = "300"
  statistic          = "Average"
  threshold          = "80"  # Umbral del 80% de uso de memoria
  alarm_description   = "Esta alarma se activa cuando el uso de memoria supera el 80%."
  dimensions = {
    InstanceId = aws_instance.web.id
  }

  alarm_actions = [aws_sns_topic.my_sns_topic.arn]
}

#Alarma para el EC2 Disco
resource "aws_cloudwatch_metric_alarm" "high_disk_usage" {
  alarm_name          = "EC2 HighDiskUsage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name        = "disk_used_percent"
  namespace          = "CWAgent"
  period             = "300"
  statistic          = "Average"
  threshold          = "90"  # Umbral del 90% de uso de disco
  alarm_description   = "Esta alarma se activa cuando el uso de disco supera el 90%."
  dimensions = {
    InstanceId = aws_instance.web.id
    #Partition  = "/"
    path       = "/"
    InstanceType = var.ec2_type
    device ="xvda1"
    fstype = "xfs"

  }

  alarm_actions = [aws_sns_topic.my_sns_topic.arn]
}

#SNS topic para el envio de alertas
resource "aws_sns_topic" "my_sns_topic" {
  name = "MyCloudWatchAlarms"
}

#SNS topic subscription
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.my_sns_topic.arn
  protocol  = "email"
  endpoint  = var.sns_email
}

output "instance_private_ip" {
  value = aws_instance.web.private_ip
}

output "instance_id" {
  value = aws_instance.web.id
}