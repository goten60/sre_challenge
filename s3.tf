
#Bucket para cloudfront
resource "aws_s3_bucket" "mi_bucket" {
  bucket_prefix = var.s3_bucket_name

  lifecycle_rule {
    id      = "mover-a-glacier"
    enabled = true

    transition {
      days          = 90  # Cambia esto al número de días después de los cuales quieres mover a Glacier
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      days = 30  # Cambia esto al número de días después de los cuales quieres mover versiones antiguas a Glacier
      storage_class   = "GLACIER"
    }

    expiration {
      days = 365  # Cambia esto al número de días después de los cuales quieres eliminar objetos
    }
  }
}

#Bucket versionado
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.mi_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# CloudFront origin access control
resource "aws_cloudfront_origin_access_control" "cdn_origin_access_control" {
  name                            = "OAC-${aws_s3_bucket.mi_bucket.id}"
  origin_access_control_origin_type = "s3"
  signing_behavior                = "no-override"
  signing_protocol                = "sigv4"
}

#cloudfront
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.mi_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.cdn_origin_access_control.id
    origin_id                = "${aws_s3_bucket.mi_bucket.id}.s3.${var.aws_region}.amazonaws.com"

  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }
  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id       = "${aws_s3_bucket.mi_bucket.id}.s3.${var.aws_region}.amazonaws.com"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress = true
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  tags = local.common_tags
}

#Bucket policy para permitir cloudfront
resource "aws_s3_bucket_policy" "mi_bucket_policy" {
  bucket = aws_s3_bucket.mi_bucket.id

  policy = <<EOF
{
    "Version": "2008-10-17",
    "Id": "PolicyForCloudFrontPrivateContent",
    "Statement": [
        {
            "Sid": "AllowCloudFrontServicePrincipal",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudfront.amazonaws.com"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${aws_s3_bucket.mi_bucket.id}/*",
            "Condition": {
                "StringEquals": {
                    "AWS:SourceArn": "arn:aws:cloudfront::${local.account_id}:distribution/${aws_cloudfront_distribution.cdn.id}"
                }
            }
        }
    ]
}
EOF
}

#Bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "mi_bucket_encryption" {
  bucket = aws_s3_bucket.mi_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

#Bucket logging
resource "aws_s3_bucket_logging" "log" {
  bucket        = aws_s3_bucket.mi_bucket.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "logs/"
}

# bucket para logs
resource "aws_s3_bucket" "log_bucket" {
  bucket_prefix =  var.s3_log_bucket_name
}

#alarma para el bucket
resource "aws_cloudwatch_metric_alarm" "storage_alarm" {
  alarm_name                = "S3 HighS3BucketStorage"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "1"
  metric_name              = "SizeBytes"
  namespace                = "AWS/S3"
  period                   = "86400"  # 1 día
  statistic                = "Average"
  threshold                = 1000000000  # Umbral en bytes (ejemplo: 1GB)

  dimensions = {
    BucketName = aws_s3_bucket.mi_bucket.bucket
    StorageType = "StandardStorage"
  }

  alarm_description = "Alarma si el almacenamiento en el bucket S3 supera 1GB"
  alarm_actions = [aws_sns_topic.my_sns_topic.arn]
}

# S3
output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.mi_bucket.bucket
}

output "s3_bucket_name_log" {
  description = "S3 bucket name log"
  value       = aws_s3_bucket.log_bucket.bucket

}

output "cloudfront_distribution_domain_name" {
  value = aws_cloudfront_distribution.cdn.domain_name
}