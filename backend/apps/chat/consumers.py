import json
import logging

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer
from django.conf import settings
from django.core.exceptions import ValidationError

from .attachments import MAX_FILES_PER_MESSAGE, model_content
from .models import (
    DEFAULT_TITLE,
    GREETING_TEXT,
    Attachment,
    Conversation,
    Message,
    title_from_prompt,
)
from .services.openai_service import stream_chat_completion

logger = logging.getLogger(__name__)

MAX_HISTORY_MESSAGES = 20  # how many prior turns to feed back into the model

SYSTEM_PROMPT = (
    "You are Nova, a friendly and precise AI assistant. "
    "Format answers in Markdown: short paragraphs, lists and tables where useful, "
    "and fenced code blocks with a language tag. "
    "Never use LaTeX; write maths in plain text or inline code (e.g. 2 × 9 = 18)."
)

# Response styles the user can pick from the composer's "+" menu.
STYLE_INSTRUCTIONS = {
    "concise": "Style: be concise. Give the shortest complete answer; skip preamble.",
    "explanatory": (
        "Style: be explanatory. Teach step by step, define terms and use an "
        "example where it helps."
    ),
    "formal": "Style: write in a clear, professional and formal tone.",
}


class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope["user"]

        if not self.user or self.user.is_anonymous:
            await self.close(code=4001)
            return

        await self.accept()

    async def receive(self, text_data=None, bytes_data=None):
        try:
            data = json.loads(text_data or "")
        except json.JSONDecodeError:
            await self.send_error("Invalid JSON payload.")
            return

        content = str(data.get("message") or "").strip()
        conversation_id = data.get("conversation_id")
        attachment_ids = data.get("attachment_ids") or []
        if not isinstance(attachment_ids, list):
            attachment_ids = []
        attachment_ids = [str(a) for a in attachment_ids][:MAX_FILES_PER_MESSAGE]
        options = data.get("options")
        if not isinstance(options, dict):
            options = {}
        style = STYLE_INSTRUCTIONS.get(str(options.get("style") or ""))
        think_longer = options.get("think") is True

        if not content and not attachment_ids:
            await self.send_error("Message cannot be empty.")
            return

        conversation = await self.get_or_create_conversation(conversation_id)

        # Save user's message (and link any files uploaded for it)
        await self.save_message(
            conversation, "user", content, attachment_ids=attachment_ids
        )

        # Build message history for the model; images switch to the vision model
        history, has_images = await self.get_recent_messages(conversation)
        if style:
            history[0]["content"] += "\n\n" + style
        model = settings.OPENAI_VISION_MODEL if has_images else None
        # "Think longer" only applies to the reasoning (text) model.
        effort = "high" if think_longer and not has_images else None

        # Tell client the conversation id (useful for a brand-new chat)
        await self.send(text_data=json.dumps({
            "type": "conversation_start",
            "conversation_id": str(conversation.id),
            "title": conversation.title,
        }))

        # Stream assistant response: "reasoning" events while the model
        # thinks, then "token" events for the answer itself.
        assistant_text = ""
        reasoning_text = ""
        try:
            async for kind, chunk in stream_chat_completion(
                history, model=model, reasoning_effort=effort
            ):
                if kind == "reasoning":
                    reasoning_text += chunk
                    event = "reasoning"
                else:
                    assistant_text += chunk
                    event = "token"
                await self.send(text_data=json.dumps({
                    "type": event,
                    "content": chunk,
                }))
        except Exception as exc:  # noqa: BLE001
            logger.warning("Streaming failed for conversation %s: %s", conversation.id, exc)
            await self.send_error(f"Model error: {exc}")
            return

        await self.save_message(
            conversation, "assistant", assistant_text, reasoning=reasoning_text
        )

        await self.send(text_data=json.dumps({
            "type": "done",
            "conversation_id": str(conversation.id),
        }))

    async def send_error(self, message):
        await self.send(text_data=json.dumps({"type": "error", "message": message}))

    @database_sync_to_async
    def get_or_create_conversation(self, conversation_id):
        if conversation_id:
            try:
                return Conversation.objects.get(id=conversation_id, user=self.user)
            except (Conversation.DoesNotExist, ValueError, ValidationError):
                pass

        # Brand-new conversation: add the same one-time greeting as the REST
        # endpoint so history fetched later looks identical.
        conv = Conversation.objects.create(user=self.user)
        Message.objects.create(conversation=conv, role="assistant", content=GREETING_TEXT)
        return conv

    @database_sync_to_async
    def save_message(self, conversation, role, content, reasoning="", attachment_ids=()):
        message = Message.objects.create(
            conversation=conversation, role=role, content=content, reasoning=reasoning
        )
        names = []
        if attachment_ids:
            # Only this user's files that aren't attached to anything yet.
            pending = Attachment.objects.filter(
                id__in=attachment_ids, user=self.user, message__isnull=True
            )
            names = list(pending.values_list("name", flat=True))
            pending.update(message=message)
        if role == "user" and conversation.title == DEFAULT_TITLE:
            conversation.title = title_from_prompt(content or " ".join(names))
        conversation.save()  # bumps updated_at

    @database_sync_to_async
    def get_recent_messages(self, conversation):
        """Returns (model_messages, has_images)."""
        msgs = list(
            conversation.messages.prefetch_related("attachments").order_by(
                "-created_at"
            )[:MAX_HISTORY_MESSAGES]
        )
        msgs.reverse()
        history = [{"role": "system", "content": SYSTEM_PROMPT}]
        has_images = False
        for index, m in enumerate(msgs):
            # Only the newest turn sends real image data; older images are
            # referred to by name to keep requests small.
            newest = index == len(msgs) - 1
            content, with_images = model_content(m, include_images=newest)
            has_images = has_images or with_images
            history.append({"role": m.role, "content": content})
        return history, has_images
