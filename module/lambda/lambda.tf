data "archive_file" "garbage-day-notification" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/upload/lambda.zip"
}

resource "aws_lambda_function" "garbage-day-notification" {
  filename      = data.archive_file.garbage-day-notification.output_path
  function_name = "notify-gabarge-day"
  role          = aws_iam_role.lambda_trash_day.arn
  handler       = "main.lambda_handler"

  source_code_hash = data.archive_file.garbage-day-notification.output_base64sha256

  runtime = "ruby2.7"

  tracing_config {
    mode = "Active" # Activate AWS X-Ray
  }

  environment {
    variables = {
      DYNAMO_DB_TABLE_NAME = var.dynamo_db_table_name
      LINE_TOKEN = var.line_token
    }
  }

  timeout                        = 30
  reserved_concurrent_executions = 50
  publish                        = true
}
