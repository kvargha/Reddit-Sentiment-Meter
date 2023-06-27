terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.region
}

// Create DynamoDB
resource "aws_dynamodb_table" "reddit-sentiment-db" {
  name = "reddit-sentiment"
  billing_mode = "PROVISIONED"
  read_capacity= "25"
  write_capacity= "25"
  attribute {
    name = "date"
    type = "S"
  }
  hash_key = "date"
}

// Create role for redditor consumer lambda
resource "aws_iam_role" "reddit-consumer-role" {
  name = "reddit-consumer-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "reddit-consumer-policy" {
  name   = "reddit-consumer-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = ["arn:aws:logs:*:*:*"]
    },{
      Effect = "Allow"
      Action = [
        "comprehend:DetectSentiment"
      ]
      Resource = ["*"]
    },{
      Effect = "Allow"
      Action = [
        "dynamodb:UpdateItem"
      ]
      Resource = ["${aws_dynamodb_table.reddit-sentiment-db.arn}"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "reddit-consumer" {
  policy_arn = aws_iam_policy.reddit-consumer-policy.arn
  role = aws_iam_role.reddit-consumer-role.name
}

// Provisioner to install dependencies in lambda package before upload it.
resource "null_resource" "reddit-consumer" {

  triggers = {
    updated_at = timestamp()
  }

  provisioner "local-exec" {
    command = "npm install"

    working_dir = "${path.module}/reddit-consumer/"
  }
}

// Archive reddit consumer lambda
data "archive_file" "reddit-consumer" {
  type        = "zip"
  source_dir  = "reddit-consumer/"
  output_path = "${path.module}/.terraform/archive_files/reddit-consumer-function.zip"

  depends_on = [null_resource.reddit-consumer]
}

// Create reddit consumer lambda
resource "aws_lambda_function" "reddit-consumer" {
  function_name    = "reddit-consumer"
  filename         = "${path.module}/.terraform/archive_files/reddit-consumer-function.zip"
  handler          = "index.handler"
  role             = aws_iam_role.reddit-consumer-role.arn
  runtime          = "nodejs18.x"
}

// Create producer

// Create a bucket
resource "aws_s3_bucket" "reddit-producer" {
  bucket = "reddit-producer"
}

// Zip files
data "archive_file" "reddit-producer" {
  type        = "zip"
  source_dir  = "./reddit-producer/"
  output_path = "./reddit-producer/reddit-producer.zip"
}

// Upload zip to s3
resource "aws_s3_object" "reddit-producer" {
  bucket = "${aws_s3_bucket.reddit-producer.id}"
  key    = "reddit-producer.zip"
  source = "${data.archive_file.reddit-producer.output_path}"
  source_hash = filemd5(data.archive_file.reddit-producer.output_path)
  etag        = filemd5(data.archive_file.reddit-producer.output_path)
}

// Create role for reddit-producer
resource "aws_iam_role" "reddit-producer-role" {
  name = "reddit-producer-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_instance_profile" "ec2-profile-reddit-producer-role" {
  name = "ec2-profile-reddit-producer-role"
  role = aws_iam_role.reddit-producer-role.name
}

resource "aws_iam_policy" "reddit-producer-policy" {
  name   = "reddit-producer-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = ["${aws_s3_bucket.reddit-producer.arn}", "${aws_s3_bucket.reddit-producer.arn}/*"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "reddit-producer" {
  policy_arn = aws_iam_policy.reddit-producer-policy.arn
  role = aws_iam_role.reddit-producer-role.name
}

resource "aws_security_group" "reddit-producer" {
  name = "reddit-producer"
  description = "Allow SSH traffic via Terraform"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "reddit-producer" {
  ami = "${var.ami-id}"
  instance_type = "${var.ec2-instance-type}"

  root_block_device {
    volume_size = 8
  }
  iam_instance_profile = aws_iam_instance_profile.ec2-profile-reddit-producer-role.name
  vpc_security_group_ids = [aws_security_group.reddit-producer.id]
  key_name = "${var.ssh-key-pair-name}"

  user_data = <<-EOL
    #!/bin/bash -xe
    sudo apt-get update
    sudo apt install awscli -y
    sudo apt install python3-pip -y
    sudo apt-get install supervisor
    sudo apt install unzip
    cd /home/ubuntu
    aws s3 cp s3://reddit-producer/reddit-producer.zip ./
    unzip -n reddit-producer.zip
    sudo mv reddit_producer.conf /etc/supervisor/conf.d/
    pip3 install -r requirements.txt
    sudo supervisorctl reread
    sudo supervisorctl update
  EOL

  tags = {
    Name = "reddit-producer"
  }

  depends_on = [aws_s3_object.reddit-producer]
}

// Create role for sentiment-api lambda
resource "aws_iam_role" "sentiment-api-role" {
  name = "sentiment-api-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "sentiment-api-policy" {
  name   = "sentiment-api-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = ["arn:aws:logs:*:*:*"]
    },{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem"
      ]
      Resource = ["${aws_dynamodb_table.reddit-sentiment-db.arn}"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "sentiment-api" {
  policy_arn = aws_iam_policy.sentiment-api-policy.arn
  role = aws_iam_role.sentiment-api-role.name
}

// Provisioner to install dependencies in lambda package before upload it.
resource "null_resource" "sentiment-api" {

  triggers = {
    updated_at = timestamp()
  }

  provisioner "local-exec" {
    command = "npm install"

    working_dir = "${path.module}/sentiment-api/"
  }
}

// Archive sentiment-api lambda
data "archive_file" "sentiment-api" {
  type        = "zip"
  source_dir  = "sentiment-api/"
  output_path = "${path.module}/.terraform/archive_files/sentiment-api-function.zip"

  depends_on = [null_resource.sentiment-api]
}

// Create sentiment-api lambda
resource "aws_lambda_function" "sentiment-api" {
  function_name    = "sentiment-api"
  filename         = "${path.module}/.terraform/archive_files/sentiment-api-function.zip"
  handler          = "index.handler"
  role             = aws_iam_role.sentiment-api-role.arn
  runtime          = "nodejs18.x"
}

// Create API Gateway to sentiment-api
resource "aws_apigatewayv2_api" "sentiment-api" {
  name          = "sentiment-api-gateway"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET"]
    allow_headers = ["*"]
    max_age = 300
  }
}

resource "aws_apigatewayv2_stage" "sentiment-api" {
  api_id = aws_apigatewayv2_api.sentiment-api.id

  name        = "prod"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.sentiment-api-gateway.arn

    format = jsonencode({
        requestId               = "$context.requestId"
        sourceIp                = "$context.identity.sourceIp"
        requestTime             = "$context.requestTime"
        protocol                = "$context.protocol"
        httpMethod              = "$context.httpMethod"
        resourcePath            = "$context.resourcePath"
        routeKey                = "$context.routeKey"
        status                  = "$context.status"
        responseLength          = "$context.responseLength"
        integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "sentiment-api" {
  api_id = aws_apigatewayv2_api.sentiment-api.id

  integration_uri    = aws_lambda_function.sentiment-api.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "sentiment-api" {
  api_id = aws_apigatewayv2_api.sentiment-api.id

  route_key = "GET /doom-level"
  target    = "integrations/${aws_apigatewayv2_integration.sentiment-api.id}"
}

resource "aws_cloudwatch_log_group" "sentiment-api-gateway" {
  name = "/aws/api_gateway/${aws_apigatewayv2_api.sentiment-api.name}"

  retention_in_days = 30
}

resource "aws_lambda_permission" "sentiment-api-gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sentiment-api.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.sentiment-api.execution_arn}/*/*"
}

# Create frontend bucket
resource "aws_s3_bucket" "doomermeter" {
  bucket = "doomermeter"
}

resource "aws_s3_bucket_ownership_controls" "doomermeter" {
  bucket = aws_s3_bucket.doomermeter.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "doomermeter" {
  bucket = aws_s3_bucket.doomermeter.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "doomermeter" {
  depends_on = [
    aws_s3_bucket_ownership_controls.doomermeter,
    aws_s3_bucket_public_access_block.doomermeter,
  ]

  bucket = aws_s3_bucket.doomermeter.id
  acl    = "public-read"
}

resource "aws_s3_bucket_policy" "doomermeter" {
  bucket = "${aws_s3_bucket.doomermeter.id}"

  policy = <<POLICY
  {
    "Version":"2012-10-17",
    "Statement":[{
      "Sid":"AddPerm",
      "Effect":"Allow",
      "Principal":"*",
      "Action":["s3:GetObject"],
      "Resource":["arn:aws:s3:::doomermeter/*"]
    }]
  }
  POLICY

  depends_on = [aws_s3_bucket_acl.doomermeter]
}

resource "aws_s3_bucket_website_configuration" "doomermeter" {
  bucket = aws_s3_bucket.doomermeter.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

// Provisioner to install dependencies in doomermeter
resource "null_resource" "doomermeter-install" {

  triggers = {
    updated_at = timestamp()
  }

  provisioner "local-exec" {
    command = "npm install"

    working_dir = "${path.module}/frontend/"
  }
}

// Creates build
resource "null_resource" "doomermeter-build" {

  triggers = {
    updated_at = timestamp()
  }

  provisioner "local-exec" {
    command = "npm run build"

    working_dir = "${path.module}/frontend/"
  }

  depends_on = [null_resource.doomermeter-install]
}

// Upload build files
resource "aws_s3_object" "doomermeter-build" {
  for_each      = fileset(var.frontend_upload_directory, "**/*.*")
  bucket        = aws_s3_bucket.doomermeter.bucket
  key           = replace(each.value, var.frontend_upload_directory, "")
  source        = "${var.frontend_upload_directory}${each.value}"
  acl           = "public-read"
  etag          = filemd5("${var.frontend_upload_directory}${each.value}")
  content_type  = lookup(var.mime_types, split(".", each.value)[length(split(".", each.value)) - 1])

  depends_on = [null_resource.doomermeter-build]
}