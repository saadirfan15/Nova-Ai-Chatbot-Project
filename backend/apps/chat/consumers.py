"""import json
import uuid

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer

from .models import Conversation, Message
from .services.openai_service import stream_chat_completion

MAX_HISTORY_MESSAGES = 20  # how many prior turns to feed back into the model


class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope["user"]

        if not self.user or self.user.is_anonymous:
            await self.close(code=4001)
            return

        await self.accept()

    async def disconnect(self, close_code):
        pass

    async def receive(self, text_data):
        data = json.loads(text_data)
        content = data.get("message", "").strip()
        conversation_id = data.get("conversation_id")

        if not content:
            await self.send_error("Message cannot be empty.")
            return

        conversation = await self.get_or_create_conversation(conversation_id)

        # Save user's message
        await self.save_message(conversation, "user", content)

        # Build message history for the model
        history = await self.get_recent_messages(conversation)

        # Tell client the conversation id (useful for a brand-new chat)
        await self.send(text_data=json.dumps({
            "type": "conversation_start",
            "conversation_id": str(conversation.id),
        }))

        # Stream assistant response
        assistant_text = ""
        try:
            async for chunk in stream_chat_completion(history):
                assistant_text += chunk
                await self.send(text_data=json.dumps({
                    "type": "token",
                    "content": chunk,
                }))
        except Exception as exc:  # noqa: BLE001
            await self.send_error(f"Model error: {exc}")
            return

        await self.save_message(conversation, "assistant", assistant_text)

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
            except (Conversation.DoesNotExist, ValueError):
                pass
        return Conversation.objects.create(id=uuid.uuid4(), user=self.user)

    @database_sync_to_async
    def save_message(self, conversation, role, content):
        Message.objects.create(
            id=uuid.uuid4(), conversation=conversation, role=role, content=content
        )
        conversation.save()  # bumps updated_at

    @database_sync_to_async
    def get_recent_messages(self, conversation):
        msgs = list(
            conversation.messages.order_by("-created_at")[:MAX_HISTORY_MESSAGES]
        )
        msgs.reverse()
        return [{"role": m.role, "content": m.content} for m in msgs]"""
import json
import uuid

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer

from .models import Conversation, Message
from .services.openai_service import stream_chat_completion

MAX_HISTORY_MESSAGES = 20


class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope["user"]

        print("\n" + "=" * 60)
        print("WEBSOCKET CONNECT REQUEST")
        print("USER:", self.user)
        print("AUTH:", getattr(self.user, "is_authenticated", False))
        print("=" * 60)

        if not self.user or self.user.is_anonymous:
            print("❌ CONNECTION REJECTED")
            await self.close(code=4001)
            return

        await self.accept()
        print("✅ WEBSOCKET CONNECTED")

    async def disconnect(self, close_code):
        print(f"❌ WEBSOCKET DISCONNECTED ({close_code})")

    async def receive(self, text_data):
        print("\n" + "=" * 60)
        print("RAW MESSAGE:")
        print(text_data)
        print("=" * 60)

        data = json.loads(text_data)

        content = data.get("message", "").strip()
        conversation_id = data.get("conversation_id")

        print("MESSAGE:", content)
        print("CONVERSATION:", conversation_id)

        if not content:
            await self.send_error("Message cannot be empty.")
            return

        conversation = await self.get_or_create_conversation(conversation_id)

        print("CONVERSATION ID:", conversation.id)

        await self.save_message(conversation, "user", content)

        history = await self.get_recent_messages(conversation)

        print("HISTORY LENGTH:", len(history))

        print("➡ SENDING conversation_start")

        await self.send(
            text_data=json.dumps(
                {
                    "type": "conversation_start",
                    "conversation_id": str(conversation.id),
                }
            )
        )

        assistant_text = ""

        try:
            async for chunk in stream_chat_completion(history):
                assistant_text += chunk

                print("➡ TOKEN:", repr(chunk))

                await self.send(
                    text_data=json.dumps(
                        {
                            "type": "token",
                            "content": chunk,
                        }
                    )
                )

            print("✅ STREAM FINISHED")

        except Exception as exc:
            print("❌ STREAM ERROR:", exc)
            await self.send_error(f"Model error: {exc}")
            return

        await self.save_message(conversation, "assistant", assistant_text)

        print("💾 ASSISTANT MESSAGE SAVED")

        print("➡ SENDING DONE")

        await self.send(
            text_data=json.dumps(
                {
                    "type": "done",
                    "conversation_id": str(conversation.id),
                }
            )
        )

    async def send_error(self, message):
        print("❌ ERROR:", message)

        await self.send(
            text_data=json.dumps(
                {
                    "type": "error",
                    "message": message,
                }
            )
        )

    @database_sync_to_async
    def get_or_create_conversation(self, conversation_id):
        if conversation_id:
            try:
                return Conversation.objects.get(
                    id=conversation_id,
                    user=self.user,
                )
            except (Conversation.DoesNotExist, ValueError):
                pass

        # Create a new conversation and add a one-time assistant greeting.
        conv = Conversation.objects.create(id=uuid.uuid4(), user=self.user)
        # Insert the greeting message so frontends that immediately fetch
        # conversation history will see the assistant welcome.
        Message.objects.create(
            id=uuid.uuid4(),
            conversation=conv,
            role="assistant",
            content="👋 Hi! I'm your AI assistant. How can I help you today?",
        )
        return conv

    @database_sync_to_async
    def save_message(self, conversation, role, content):
        Message.objects.create(
            id=uuid.uuid4(),
            conversation=conversation,
            role=role,
            content=content,
        )
        conversation.save()

    @database_sync_to_async
    def get_recent_messages(self, conversation):
        msgs = list(
            conversation.messages.order_by("-created_at")[
                :MAX_HISTORY_MESSAGES
            ]
        )
        msgs.reverse()

        return [
            {
                "role": m.role,
                "content": m.content,
            }
            for m in msgs
        ]
