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