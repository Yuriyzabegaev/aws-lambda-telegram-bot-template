variable "lambda_name" {
  type    = string
  default = "finnno-bot"
}

variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "telegram_token" {
  type      = string
  sensitive = true
}

variable "allowed_users" {
  type        = string
  description = "Comma-separated list of allowed Telegram user IDs"
}
