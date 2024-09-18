
#Sourcing Lambda code transformed into an archive
data "archive_file" "source_lambda_code" {
  type        = "zip"
  source_dir  = "${path.module}/../code/source_lambda"
  output_path = "${path.module}/../${var.source_lambda_name}.zip"
}

#Reporting analysis Lambda code transformed into an archive
data "archive_file" "report_lambda_code" {
  type        = "zip"
  source_dir  = "${path.module}/../code/report_lambda"
  output_path = "${path.module}/../${var.report_lambda_name}.zip"
}

#Creating a .zip with dependencies in order to upload a layer to AWS
data "archive_file" "layer" {
  type        = "zip"
  source_dir  = "${path.module}/../layer"
  output_path = "${path.module}/../layer.zip"
  depends_on  = [null_resource.pip_install]
}

#Required IAM role for Lambdas
resource "aws_iam_role" "iam_for_lambda" {
  name = "lambda-iam-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

#Configuring the layer resource itself. 
resource "aws_lambda_layer_version" "layer" {
  layer_name          = "data-quest-layer"
  filename            = data.archive_file.layer.output_path
  source_code_hash    = data.archive_file.layer.output_base64sha256
  compatible_runtimes = ["python3.9"]
}

#Creating the Sourcing Lambda resource
resource "aws_lambda_function" "source_lambda" {
  function_name    = var.source_lambda_name
  handler          = "source_lambda.main"
  runtime          = var.python_version
  filename         = data.archive_file.source_lambda_code.output_path
  source_code_hash = data.archive_file.source_lambda_code.output_base64sha256
  role             = aws_iam_role.iam_for_lambda.arn
  layers           = [aws_lambda_layer_version.layer.arn]
  depends_on       = [aws_cloudwatch_log_group.source_lambda_log_group]
  timeout = 120

   environment {
    variables = {
      BUCKET = var.data_quest_bucket_name,
      BLS_GOV_URL = var.bls_gov_url,
      DATAUSA_URL = var.datausa_url
    }
  }
}

#Creating the Reporting analysis Lambda resource
resource "aws_lambda_function" "report_lambda" {
  function_name    = var.report_lambda_name
  handler          = "report_lambda.main"
  runtime          = var.python_version
  filename         = data.archive_file.report_lambda_code.output_path
  source_code_hash = data.archive_file.report_lambda_code.output_base64sha256
  role             = aws_iam_role.iam_for_lambda.arn
  layers           = [aws_lambda_layer_version.layer.arn, local.pandas_layer]
  depends_on       = [aws_cloudwatch_log_group.report_lambda_log_group]
  timeout = 120

   environment {
    variables = {
      S3_BLS_CSV_FILE = var.s3_bls_gov_current_file,
      S3_DATAUSA_FILE = var.s3_datausa_file
    }
  }
}

#Using AWS Lambda Managed Layer for Pandas as file may get too large if specified in requirements.txt
locals {
  pandas_layer = "arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python39:25"
}


#Providing a trigger based on a hash means for the command to run again if there is a change 
#Install Python dependencies into layer/python.  Command is required for running on Ubuntu 24.04.1
resource "null_resource" "pip_install" {
  triggers = {
    shell_hash = "${sha256(file("${path.module}/../requirements.txt"))}"
  }

  provisioner "local-exec" {
    command = "/usr/bin/${var.python_version} -m pip install --upgrade -r ${path.module}/../requirements.txt --platform manylinux2014_x86_64 --only-binary=:all: -t ${path.module}/../layer/python"
  }
}

# IAM policy allowing S3 access to bucket
resource "aws_iam_policy" "s3_policy" {
  name = "function-s3-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# For simplicity, using this basic IAM policy allowing CloudWatch logging for Lambda
data "aws_iam_policy" "lambda_basic_execution_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# For simplicity, using this basic Lambda SQS IAM policy 
data "aws_iam_policy" "lambda_sqs_execution_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

#Attaching IAM policy to Lambda allowing CloudWatch logging for Lambda
resource "aws_iam_role_policy_attachment" "function_logging_policy_attachment" {
  role = aws_iam_role.iam_for_lambda.id
  policy_arn = data.aws_iam_policy.lambda_basic_execution_policy.arn
}

#Attaching IAM policy to Lambda allowing S3 access to bucket
resource "aws_iam_role_policy_attachment" "S3-access-policy" {
    role = aws_iam_role.iam_for_lambda.id
    policy_arn = aws_iam_policy.s3_policy.arn
}

#Attaching IAM policy to Lambda for SQS access
resource "aws_iam_role_policy_attachment" "sqs-access-policy" {
    role = aws_iam_role.iam_for_lambda.id
    policy_arn = data.aws_iam_policy.lambda_sqs_execution_policy.arn
}

#CloudWatch log group for Sourcing Lambda. Referenced in Lambda resource
resource "aws_cloudwatch_log_group" "source_lambda_log_group" {
  name              = "/aws/lambda/${var.source_lambda_name}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}

#CloudWatch log group for Reporting analysis Lambda. Referenced in Lambda resource
resource "aws_cloudwatch_log_group" "report_lambda_log_group" {
  name              = "/aws/lambda/${var.report_lambda_name}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}

#Creatin g an EventBridge Rule resource to run on a daily schedule
resource "aws_cloudwatch_event_rule" "data_quest_lambda_event_rule" {
  name = "data-quest-lambda-event-rule"
  description = "scheduled to run every day"
  schedule_expression = "rate(1 day)"
}

#Creating an EventBridge Target resource for the Sourcing Lambda
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.data_quest_lambda_event_rule.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.source_lambda.arn
}

#Configuring Lambda Permission for Event Bridge
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.source_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.data_quest_lambda_event_rule.arn
}

#Creating SQS Queue
resource "aws_sqs_queue" "s3-notifications-sqs" {
  name = "s3-notifications-sqs"
  message_retention_seconds = 3600
  visibility_timeout_seconds = 180
}

#Creating SQS Queue Policy
resource "aws_sqs_queue_policy" "s3_notifications_policy" {
  queue_url = aws_sqs_queue.s3-notifications-sqs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:*"
        Resource = aws_sqs_queue.s3-notifications-sqs.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = var.data_quest_bucket_arn
          }
        }
      }
    ]
  })
}

# Creating S3 bucket notification configuration when the 
# datausa.io file is written
resource "aws_s3_bucket_notification" "s3_notification" {
  bucket = var.data_quest_bucket_name

  queue {
    events    = ["s3:ObjectCreated:*"]
    queue_arn = aws_sqs_queue.s3-notifications-sqs.arn
    filter_prefix = "datausa.json"
  }

  depends_on = [aws_sqs_queue_policy.s3_notifications_policy]
}

# Creating an Event Source mapping so that the Reporting Analysis
# Lambda gets triggered when a message arrives in the SQS queue
resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  event_source_arn = aws_sqs_queue.s3-notifications-sqs.arn
  enabled          = true
  function_name    = "${aws_lambda_function.report_lambda.arn}"
  batch_size       = 1
}