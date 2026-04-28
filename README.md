# Telegram Bot on AWS Lambda Template Project
I love building telegram bots for me and my friends!
I also don't love paying for a VPS to host them. But why pay if you can host them for free, as AWS serverless functions?
The free tier limits are far beyond what one might need for a personal or a non-commercial project.

This project contains:
- a hello-world telegram bot in Python, built for AWS Lambda integration.
- a collection of bash scripts to deploy it to AWS automatically.

I use this project as a start when I code my new bots, and it saves me hours of painful configuration. Hope it will be useful for someone else as well.

# Prerequisite 
You will need:
- an AWS account (will require to bind your bank card) and AWS cli installed and authorized.
- `uv` installed.
- telegram bot created with @BotFather, and its `TELEGRAM_BOT_TOKEN`.
- your telegram account id, as the hello-world bot responds only to the allow-list of users.

# Deployment
TLDR:
```
export ALLOWED_USERS=<your_telegram_account_id>
export TELEGRAM_BOT_TOKEN=<your_telegram_bot_token>
export LAMBDA_NAME=<name_of_your_choice>
bash scripts/build.bash && \
bash scripts/deploy.bash && \
bash scripts/register_telegram_webhook.bash && \
bash scripts/set_cloudwatch_retention.bash && \
bash scripts/add_allowed_users.bash
```
Now in detail:
- `build.bash` composes the code and its dependencies in one archive `dist/lambda.zip`.
- `deploy.bash` pushes it to AWS, creates required IAM roles and the api gateway.
- `register_telegram_webhook.bash` registers the webhook in telegram and sets the SSM entry with the `TELEGRAM_BOT_TOKEN`.
- `set_cloudwatch_retention.bash` sets logs retention to 3 days. It's unlimited by default which might cost money.
- `add_allowed_users.bash` sets the SSM entry for the list of allowed users. They must be comma separated in the `ALLOWED_USERS` environmental variable.

# Remove from AWS
One more script completely removes all the entities related to this function from AWS:
```
LAMBDA_NAME=<name_of_your_choice> bash scripts/uninstall.bash
``` 

# Disclaimer
Always set Billing Alerts on AWS. The responsibility is on you.