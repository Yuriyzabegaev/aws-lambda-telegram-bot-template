resource "aws_ssm_parameter" "telegram_token" {
  name  = "/${var.lambda_name}/telegram-token"
  type  = "SecureString"
  value = var.telegram_token
}

resource "aws_ssm_parameter" "allowed_users" {
  name  = "/${var.lambda_name}/allowed-users"
  type  = "StringList"
  value = var.allowed_users
}
