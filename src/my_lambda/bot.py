import asyncio
import json
import os
import boto3
from telegram import Update
from telegram.ext import (
    ApplicationBuilder,
    CommandHandler,
    MessageHandler,
    ContextTypes,
    filters,
)

from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.typing import LambdaContext

logger = Logger()


def _get_ssm_parameter(name: str, with_decryption: bool = False) -> str:
    ssm = boto3.client("ssm")
    response = ssm.get_parameter(Name=name, WithDecryption=with_decryption)
    return response["Parameter"]["Value"]


AWS_LAMBDA_FUNCTION_NAME = os.environ["AWS_LAMBDA_FUNCTION_NAME"]
TELEGRAM_TOKEN = _get_ssm_parameter(
    f"/{AWS_LAMBDA_FUNCTION_NAME}/telegram-token", with_decryption=True
)
ALLOWED_USERS = {
    int(uid.strip())
    for uid in _get_ssm_parameter(f"/{AWS_LAMBDA_FUNCTION_NAME}/allowed-users").split(
        ","
    )
}


def require_auth(handler):
    def auth_middleware(update: Update, context):
        user_id = -1
        if update.effective_user is not None:
            user_id = update.effective_user.id
        if user_id not in ALLOWED_USERS:
            logger.info({"message": "Unauthorized access attempt", "user_id": user_id})
            return
        return handler(update, context)

    return auth_middleware


@require_auth
async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    assert update.effective_user is not None and update.message is not None
    await update.message.reply_text(f"You said {update.message.text}")


@require_auth
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    logger.info({"message": "Entering /start"})
    assert update.message is not None
    await update.message.reply_text("Hello world!")


def _process_update(event: dict) -> None:
    app = ApplicationBuilder().token(TELEGRAM_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))

    async def main():
        logger.info({"message": "Start processing update"})
        try:
            await app.initialize()
            update = Update.de_json(json.loads(event["body"]), app.bot)
            await app.process_update(update)
            await app.shutdown()
        except Exception as e:
            logger.exception(e)

    asyncio.run(main())


@logger.inject_lambda_context
def handler(event: dict, context: "LambdaContext") -> dict:
    if event.get("_async"):
        # The original request will not contain this.
        _process_update(event)
        return {"statusCode": 200, "body": "ok"}

    # Spawning the same lambda which will do the heavy lifting.
    boto3.client("lambda").invoke(
        FunctionName=context.function_name,
        InvocationType="Event",
        Payload=json.dumps({"body": event["body"], "_async": True}),
    )

    # Acknowledge Telegram immediately to prevent retries on slow processing.
    return {"statusCode": 200, "body": "ok"}
