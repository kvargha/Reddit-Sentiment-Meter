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

resource "aws_sqs_queue" "sentiment_queue" {
  name = var.sqs_name
}

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
    }, {
      Effect = "Allow"
      Action = [
        "sqs:SendMessage"
      ]
      Resource = ["${aws_sqs_queue.sentiment_queue.arn}"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "reddit-consumer" {
  policy_arn = aws_iam_policy.reddit-consumer-policy.arn
  role = aws_iam_role.reddit-consumer-role.name
}

resource "aws_lambda_function" "reddit-consumer" {
  reserved_concurrent_executions = 1

  function_name    = "reddit-consumer"
  filename         = "./reddit-consumer/target/reddit-consumer-1.0.0.jar"
  source_code_hash = filebase64sha256("./reddit-consumer/target/reddit-consumer-1.0.0.jar")
  handler          = "index.handler"
  role             = aws_iam_role.reddit-consumer-role.arn
  runtime          = "java17"
}