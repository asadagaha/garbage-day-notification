resource "aws_iam_role" "lambda_trash_day" {
  name = "GarbageDayLambdaRole"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "lambda.amazonaws.com"
          },
          "Effect" : "Allow",
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_trash_day.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy_attachment" "lambda_dynamo_db_execution" {
  role       = aws_iam_role.lambda_trash_day.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaDynamoDBExecutionRole"
}
resource "aws_iam_role_policy_attachment" "lambda_dynamo_db_full_access" {
  role       = aws_iam_role.lambda_trash_day.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}