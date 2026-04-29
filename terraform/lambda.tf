resource "aws_lambda_function" "main" {
  function_name    = var.lambda_name
  filename         = "${path.module}/../dist/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/../dist/lambda.zip")

  timeout = 150
  runtime = "python3.12"
  handler = "my_lambda.bot.handler"
  role    = aws_iam_role.lambda.arn

  depends_on = [aws_cloudwatch_log_group.lambda]
}
