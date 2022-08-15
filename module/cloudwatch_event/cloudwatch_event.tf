resource "aws_cloudwatch_event_rule" "garbage_day_notification" {
    name                = "garbage_day_notification"
    description         = "notify garbage day every week"
    schedule_expression = "cron(0 12 ? * SUN *)"
}

resource "aws_cloudwatch_event_target" "garbage_day_notification" {
    rule      = aws_cloudwatch_event_rule.garbage_day_notification.name
    target_id = "garbage_day_notification"
    arn       = var.lambda_arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_garbage_day_notification" {
    statement_id  = "AllowExecutionFromCloudWatch"
    action        = "lambda:InvokeFunction"
    function_name = var.function_name
    principal     = "events.amazonaws.com"
    source_arn    = aws_cloudwatch_event_rule.garbage_day_notification.arn
}