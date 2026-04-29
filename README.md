# Telegram Bot on AWS Lambda Template Project
I love building telegram bots for me and my friends!
I also don't love paying for a VPS to host them. But why pay if you can host them for free, as AWS serverless functions?
The free tier limits are far beyond what one might need for a personal or a non-commercial project.

This project contains:
- a hello-world telegram bot in Python, built for AWS Lambda integration.
- a collection of bash scripts and terraform configs to deploy it to AWS automatically.

I use this project as a start when I code my new bots, and it saves me hours of painful configuration. Hope it will be useful for someone else as well.

# Prerequisite 
You will need:
- an AWS account (will require to bind your bank card) and AWS cli installed and authorized.
- `uv` installed.
- `terraform` installed.
- telegram bot created with @BotFather, and its `TELEGRAM_BOT_TOKEN`.
- your telegram account id, as the hello-world bot responds only to the allow-list of users.

# Deployment
First, rename `.env.example` into `.env` and set your values for the environmental variables.
Do the same for `terraform/terraform.tfvars.example` -> `terraform/terraform.tfvars`.

TLDR:
```
bash scripts/build.bash && \
terraform -chdir=./terraform init && \
terraform -chdir=./terraform apply && \
bash scripts/register_telegram_webhook.bash
```
Now in detail:
- `build.bash` composes the code and its dependencies in one archive `dist/lambda.zip`.
- `terraform init` initializes terraform.
- `terraform apply` pushes it to AWS.
- `register_telegram_webhook.bash` registers the webhook in telegram.

# Remove from AWS
This command removes all the entities related to this function from AWS:
```
terraform -chdir=./terraform destroy
``` 

# Disclaimer
Always set Billing Alerts on AWS. The responsibility is on you.