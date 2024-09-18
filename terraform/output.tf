
output "sourcing_lambda_name" {
  description = "The name of the Sourcing Lambda"
  value       = aws_lambda_function.source_lambda.id
}

output "reporting_lambda_name" {
  description = "The name of the Reporting Lambda"
  value       = aws_lambda_function.report_lambda.id
}

output "lambda_iam_role_name" {
  description = "The name of the Lambda IAM role"
  value       = aws_iam_role.iam_for_lambda.id
}


output "lambda_S3_policy_name" {
  description = "The name of the Lambda S3 Policy"
  value       = aws_iam_policy.s3_policy.id
}

output "sourcing_lambda_cloudwatch_log_group" {
  description = "CloudWatch Log Group for Sourcing Lambda"
  value       = aws_cloudwatch_log_group.source_lambda_log_group.id
}

output "reporting_lambda_cloudwatch_log_group" {
  description = "CloudWatch Log Group for Reporting Lambda"
  value       = aws_cloudwatch_log_group.report_lambda_log_group.id
}

output "sourcing_lambda_aws_cloudwatch_event_target" {
  description = "EventBridge Target resource for the Sourcing Lambda"
  value       = aws_cloudwatch_event_target.lambda_target.id
}

output "sourcing_lambda_aws_event_bridge_permission" {
  description = "Sourcing Lambda Permission for Event Bridge"
  value       = aws_lambda_permission.allow_eventbridge.id
}

output "s3_notifications_sqs_queue" {
  description = "SQS Queue"
  value       = aws_sqs_queue.s3-notifications-sqs.id
}

output "sqs_queue_policy" {
  description = "SQS Queue Policy"
  value       = aws_sqs_queue_policy.s3_notifications_policy.id
}

output "s3_notification" {
  description = "S3 bucket notification configuration"
  value       = aws_s3_bucket_notification.s3_notification.id
}

output "event_source_mapping" {
  description = " Event Source mapping so that the Reporting Analysis Lambda gets triggered when a message arrives in the SQS queue"
  value       = aws_lambda_event_source_mapping.event_source_mapping.id
}