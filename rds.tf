

resource "aws_kms_key" "kms_rds" {
  description = "KMS Key for RDS"
}

resource "aws_security_group" "rds_sg" {
  vpc_id = module.vpc.vpc_id
  name = "rds_sg"
  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "rds_eggress" {
  security_group_id = aws_security_group.rds_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#role
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name_prefix        = "rds-enhanced-monitoring-"
  assume_role_policy = data.aws_iam_policy_document.rds_enhanced_monitoring.json
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

data "aws_iam_policy_document" "rds_enhanced_monitoring" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

#########

# Crear la instancia RDS
resource "aws_db_instance" "db_instance" {
  identifier              = var.db_identifier
  engine                 = "mysql"
  engine_version         = "8.0.39"  # Cambia a la versión que necesites
  instance_class         = "db.t4g.small"  # Cambios aquí para utilizar T4.small
  allocated_storage       = 20
  max_allocated_storage   = 50
  storage_type           = "gp3"
  db_subnet_group_name   = aws_db_subnet_group.my_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  multi_az               = true
  username               = var.db_user
  enabled_cloudwatch_logs_exports  = ["error", "general"]

  monitoring_interval    = 60
  monitoring_role_arn    = aws_iam_role.rds_enhanced_monitoring.arn


  db_name          = var.db_name
  backup_retention_period = 7  # Retención de backups automáticos por 7 días

  skip_final_snapshot     = true  # debe ser falso para ambiente productivos
  final_snapshot_identifier = "snapshot-final-mi-db-instance"
  deletion_protection     = false  # debe ser true para ambiente productivos


  #Se recomienda pero no es compatible con replicas lectura
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.kms_rds.key_id

  tags = local.common_tags

  # Habilitar el almacenamiento en el momento de la instancia
  storage_encrypted = true  # Opcional: Habilita para almacenamiento encriptado
}

/*
resource "aws_db_instance" "replica-rds" {
  instance_class       = "db.t4g.small"
  skip_final_snapshot  = true
  backup_retention_period = 7
  replicate_source_db = aws_db_instance.db_instance.identifier
}
 */

# Crear un grupo de subred para RDS
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "My DB Subnet Group"
  }
}

# Alarmas de CloudWatch
resource "aws_cloudwatch_metric_alarm" "cpu_utilization_alarm" {
  alarm_name          = "High CPU Utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name        = "CPUUtilization"
  namespace          = "AWS/RDS"
  period             = "300"  # Periodo de 5 minutos
  statistic          = "Average"
  threshold          = 80  # Umbral del 80%

  dimensions = {
    DBInstanceIdentifier = var.db_identifier
  }

  alarm_description = "Alarma si la utilización de CPU supera el 80%"
  alarm_actions = [aws_sns_topic.my_sns_topic.arn]
}

resource "aws_cloudwatch_metric_alarm" "database_connections_alarm" {
  alarm_name          = "High Database Connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name        = "DatabaseConnections"
  namespace          = "AWS/RDS"
  period             = "300"  # Periodo de 5 minutos
  statistic          = "Average"
  threshold          = 100  # Umbral de conexiones

  dimensions = {
    DBInstanceIdentifier = var.db_identifier
  }

  alarm_description = "Alarma si las conexiones a la Base de Datos superan 100"
  alarm_actions = [aws_sns_topic.my_sns_topic.arn]
}

resource "aws_cloudwatch_metric_alarm" "free_storage_space_alarm" {
  alarm_name          = "Low Free Storage Space"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name        = "FreeStorageSpace"
  namespace          = "AWS/RDS"
  period             = "300"  # Periodo de 5 minutos
  statistic          = "Average"
  threshold          = 50000000  # Umbral de espacio libre en bytes (ejemplo: 50MB)

  dimensions = {
    DBInstanceIdentifier = var.db_identifier
  }

  alarm_description = "Alarma si el espacio libre en disco es menor de 50MB"
  alarm_actions = [aws_sns_topic.my_sns_topic.arn]
}

output "db_instance_endpoint" {
  value = aws_db_instance.db_instance.endpoint
}

output "db_instance_id" {
  value = aws_db_instance.db_instance.id
}

output "db_instance_id2" {
  value = aws_db_instance.db_instance.resource_id
}



