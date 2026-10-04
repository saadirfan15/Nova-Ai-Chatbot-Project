import json
import shutil
import struct
import tempfile
import zlib
from unittest.mock import patch

from asgiref.sync import sync_to_async
from channels.testing import WebsocketCommunicator
from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase, TransactionTestCase, override_settings
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import AccessToken

from config.asgi import application

from .models import (
    DEFAULT_TITLE,
    GREETING_TEXT,
    Attachment,
    Conversation,
    title_from_prompt,
)

User = get_user_model()


class TitleFromPromptTests(SimpleTestCase):
    def test_short_prompt(self):
        self.assertEqual(title_from_prompt("  hello   there "), "hello there")

    def test_long_prompt_is_truncated(self):
        title = title_from_prompt("supercalifragilistic expialidocious words keep going on")
        self.assertLessEqual(len(title), 32)
        self.assertTrue(title.endswith("..."))

    def test_empty_prompt(self):
        self.assertEqual(title_from_prompt("   "), DEFAULT_TITLE)


class ConversationApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user("dave", "dave@example.com", "S3cure!pass")
        self.other = User.objects.create_user("eve", "eve@example.com", "S3cure!pass")
        self.client.force_authenticate(self.user)

    def test_create_returns_greeting(self):
        resp = self.client.post("/api/chat/conversations/")
        self.assertEqual(resp.status_code, 201)
        self.assertEqual(resp.data["title"], DEFAULT_TITLE)
        self.assertEqual(len(resp.data["messages"]), 1)
        self.assertEqual(resp.data["messages"][0]["content"], GREETING_TEXT)

    def test_list_only_own_conversations(self):
        Conversation.objects.create(user=self.user)
        Conversation.objects.create(user=self.other)
        resp = self.client.get("/api/chat/conversations/")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(len(resp.data), 1)

    def test_cannot_read_or_delete_others_conversation(self):
        conv = Conversation.objects.create(user=self.other)
        self.assertEqual(self.client.get(f"/api/chat/conversations/{conv.id}/").status_code, 404)
        self.assertEqual(self.client.delete(f"/api/chat/conversations/{conv.id}/").status_code, 404)

    def test_delete_own_conversation(self):
        conv = Conversation.objects.create(user=self.user)
        self.assertEqual(self.client.delete(f"/api/chat/conversations/{conv.id}/").status_code, 204)
        self.assertFalse(Conversation.objects.filter(id=conv.id).exists())


async def _fake_stream(messages, model=None, reasoning_effort=None):
    yield ("reasoning", "The user greets me. ")
    yield ("reasoning", "Reply politely.")
    for chunk in ["Hello", " world"]:
        yield ("content", chunk)


async def _failing_stream(messages, model=None, reasoning_effort=None):
    raise RuntimeError("boom")
    yield  # pragma: no cover - makes this an async generator


class ChatConsumerTests(TransactionTestCase):
    def setUp(self):
        self.user = User.objects.create_user("frank", "frank@example.com", "S3cure!pass")
        self.token = str(AccessToken.for_user(self.user))

    async def _connect(self, token=None):
        query = f"?token={token}" if token else ""
        communicator = WebsocketCommunicator(application, f"/ws/chat/{query}")
        connected, code = await communicator.connect()
        return communicator, connected, code

    async def _receive_until_done(self, communicator):
        events = []
        while True:
            event = json.loads(await communicator.receive_from(timeout=5))
            events.append(event)
            if event["type"] in ("done", "error"):
                return events

    async def test_rejects_missing_token(self):
        _, connected, code = await self._connect()
        self.assertFalse(connected)
        self.assertEqual(code, 4001)

    async def test_rejects_invalid_token(self):
        _, connected, code = await self._connect("not-a-jwt")
        self.assertFalse(connected)
        self.assertEqual(code, 4001)

    @patch("apps.chat.consumers.stream_chat_completion", _fake_stream)
    async def test_streams_reply_saves_messages_and_sets_title(self):
        communicator, connected, _ = await self._connect(self.token)
        self.assertTrue(connected)

        await communicator.send_to(text_data=json.dumps({"message": "What is Django exactly?"}))
        events = await self._receive_until_done(communicator)
        await communicator.disconnect()

        self.assertEqual(events[0]["type"], "conversation_start")
        self.assertEqual(events[0]["title"], "What is Django exactly?")
        tokens = "".join(e["content"] for e in events if e["type"] == "token")
        self.assertEqual(tokens, "Hello world")
        thoughts = "".join(e["content"] for e in events if e["type"] == "reasoning")
        self.assertEqual(thoughts, "The user greets me. Reply politely.")
        # All reasoning arrives before the first answer token.
        kinds = [e["type"] for e in events if e["type"] in ("reasoning", "token")]
        self.assertEqual(kinds, ["reasoning", "reasoning", "token", "token"])
        self.assertEqual(events[-1]["type"], "done")

        conv = await sync_to_async(Conversation.objects.get)(id=events[0]["conversation_id"])
        self.assertEqual(conv.title, "What is Django exactly?")
        rows = await sync_to_async(
            lambda: list(conv.messages.values_list("role", "reasoning"))
        )()
        self.assertEqual([r[0] for r in rows], ["assistant", "user", "assistant"])
        self.assertEqual(rows[-1][1], "The user greets me. Reply politely.")

    @patch("apps.chat.consumers.stream_chat_completion", _fake_stream)
    async def test_invalid_conversation_id_creates_new_conversation(self):
        communicator, _, _ = await self._connect(self.token)
        await communicator.send_to(
            text_data=json.dumps({"message": "hi", "conversation_id": "not-a-uuid"})
        )
        events = await self._receive_until_done(communicator)
        await communicator.disconnect()
        self.assertEqual(events[-1]["type"], "done")

    async def test_empty_message_and_bad_json_return_errors(self):
        communicator, _, _ = await self._connect(self.token)
        await communicator.send_to(text_data=json.dumps({"message": "   "}))
        self.assertEqual(json.loads(await communicator.receive_from())["type"], "error")
        await communicator.send_to(text_data="{not json")
        self.assertEqual(json.loads(await communicator.receive_from())["type"], "error")
        await communicator.disconnect()

    @patch("apps.chat.consumers.stream_chat_completion", _failing_stream)
    async def test_model_error_is_reported(self):
        communicator, _, _ = await self._connect(self.token)
        await communicator.send_to(text_data=json.dumps({"message": "hi"}))
        events = await self._receive_until_done(communicator)
        await communicator.disconnect()
        self.assertEqual(events[-1]["type"], "error")
        self.assertIn("boom", events[-1]["message"])


_TEMP_MEDIA = tempfile.mkdtemp(prefix="nova-test-media-")


def _png_bytes():
    raw = b"\x00\xff\x00\x00"
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


@override_settings(MEDIA_ROOT=_TEMP_MEDIA)
class AttachmentApiTests(APITestCase):
    @classmethod
    def tearDownClass(cls):
        super().tearDownClass()
        shutil.rmtree(_TEMP_MEDIA, ignore_errors=True)

    def setUp(self):
        self.user = User.objects.create_user("gina", "gina@example.com", "S3cure!pass")
        self.client.force_authenticate(self.user)

    def _upload(self, name, data):
        return self.client.post(
            "/api/chat/attachments/",
            {"file": SimpleUploadedFile(name, data)},
            format="multipart",
        )

    def test_text_file_upload_extracts_text(self):
        resp = self._upload("notes.md", b"# Shopping\n- milk")
        self.assertEqual(resp.status_code, 201)
        self.assertEqual(resp.data["kind"], "document")
        attachment = Attachment.objects.get(id=resp.data["id"])
        self.assertIn("- milk", attachment.extracted_text)
        self.assertIsNone(attachment.message)

    def test_image_upload(self):
        resp = self._upload("photo.png", _png_bytes())
        self.assertEqual(resp.status_code, 201)
        self.assertEqual(resp.data["kind"], "image")
        self.assertEqual(resp.data["content_type"], "image/png")

    def test_unsupported_type_rejected(self):
        resp = self._upload("setup.exe", b"MZ")
        self.assertEqual(resp.status_code, 400)
        self.assertIn("Unsupported", resp.data["detail"])

    def test_oversized_image_rejected(self):
        resp = self._upload("huge.png", b"0" * (4 * 1024 * 1024 + 1))
        self.assertEqual(resp.status_code, 400)

    def test_only_owner_can_download(self):
        attachment_id = self._upload("a.txt", b"secret").data["id"]
        ok = self.client.get(f"/api/chat/attachments/{attachment_id}/file/")
        self.assertEqual(ok.status_code, 200)
        self.assertEqual(b"".join(ok.streaming_content), b"secret")

        other = User.objects.create_user("hank", "hank@example.com", "S3cure!pass")
        self.client.force_authenticate(other)
        self.assertEqual(
            self.client.get(f"/api/chat/attachments/{attachment_id}/file/").status_code,
            404,
        )


@override_settings(MEDIA_ROOT=_TEMP_MEDIA, OPENAI_VISION_MODEL="vision-model")
class ChatConsumerAttachmentTests(TransactionTestCase):
    def setUp(self):
        self.user = User.objects.create_user("ivy", "ivy@example.com", "S3cure!pass")
        self.token = str(AccessToken.for_user(self.user))
        self.calls = []
        self.efforts = []

    async def _capture_stream(self, messages, model=None, reasoning_effort=None):
        self.calls.append((messages, model))
        self.efforts.append(reasoning_effort)
        yield ("content", "ok")

    async def _send(self, payload):
        communicator = WebsocketCommunicator(application, f"/ws/chat/?token={self.token}")
        await communicator.connect()
        await communicator.send_to(text_data=json.dumps(payload))
        events = []
        while True:
            event = json.loads(await communicator.receive_from(timeout=5))
            events.append(event)
            if event["type"] in ("done", "error"):
                break
        await communicator.disconnect()
        return events

    def _make(self, name, data, kind, content_type, text=""):
        return Attachment.objects.create(
            user=self.user,
            file=SimpleUploadedFile(name, data),
            name=name,
            content_type=content_type,
            size=len(data),
            kind=kind,
            extracted_text=text,
        )

    async def test_document_text_reaches_model_and_is_linked(self):
        doc = await sync_to_async(self._make)(
            "todo.txt", b"buy milk", "document", "text/plain", text="buy milk"
        )
        with patch("apps.chat.consumers.stream_chat_completion", self._capture_stream):
            events = await self._send(
                {"message": "Summarise this", "attachment_ids": [str(doc.id)]}
            )
        self.assertEqual(events[-1]["type"], "done")
        messages, model = self.calls[0]
        self.assertIsNone(model)  # text-only turn uses the default model
        self.assertIn('<file name="todo.txt">', messages[-1]["content"])
        self.assertIn("buy milk", messages[-1]["content"])
        await sync_to_async(doc.refresh_from_db)()
        self.assertIsNotNone(doc.message_id)

    async def test_image_only_message_uses_vision_model(self):
        img = await sync_to_async(self._make)(
            "cat.png", _png_bytes(), "image", "image/png"
        )
        with patch("apps.chat.consumers.stream_chat_completion", self._capture_stream):
            events = await self._send({"message": "", "attachment_ids": [str(img.id)]})
        self.assertEqual(events[-1]["type"], "done")
        self.assertEqual(events[0]["title"], "cat.png")
        messages, model = self.calls[0]
        self.assertEqual(model, "vision-model")
        parts = messages[-1]["content"]
        self.assertEqual(parts[0]["type"], "text")
        self.assertTrue(parts[1]["image_url"]["url"].startswith("data:image/png;base64,"))

    async def test_cannot_attach_someone_elses_file(self):
        other = await sync_to_async(User.objects.create_user)(
            "jay", "jay@example.com", "S3cure!pass"
        )
        foreign = await sync_to_async(Attachment.objects.create)(
            user=other,
            file=SimpleUploadedFile("x.txt", b"x"),
            name="x.txt",
            content_type="text/plain",
            size=1,
            kind="document",
            extracted_text="TOP SECRET",
        )
        with patch("apps.chat.consumers.stream_chat_completion", self._capture_stream):
            await self._send({"message": "hi", "attachment_ids": [str(foreign.id)]})
        messages, _ = self.calls[0]
        self.assertNotIn("TOP SECRET", messages[-1]["content"])
        await sync_to_async(foreign.refresh_from_db)()
        self.assertIsNone(foreign.message_id)

    async def test_style_and_think_longer_options(self):
        with patch("apps.chat.consumers.stream_chat_completion", self._capture_stream):
            await self._send(
                {"message": "hi", "options": {"style": "concise", "think": True}}
            )
            await self._send({"message": "hi again", "options": {"style": "bogus"}})
        first_system = self.calls[0][0][0]["content"]
        self.assertIn("be concise", first_system)
        self.assertEqual(self.efforts[0], "high")
        second_system = self.calls[1][0][0]["content"]
        self.assertNotIn("Style:", second_system)
        self.assertIsNone(self.efforts[1])

    async def test_think_longer_is_ignored_for_images(self):
        img = await sync_to_async(self._make)("p.png", _png_bytes(), "image", "image/png")
        with patch("apps.chat.consumers.stream_chat_completion", self._capture_stream):
            await self._send(
                {"message": "", "attachment_ids": [str(img.id)], "options": {"think": True}}
            )
        self.assertEqual(self.calls[0][1], "vision-model")
        self.assertIsNone(self.efforts[0])

