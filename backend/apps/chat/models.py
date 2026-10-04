import uuid
from django.conf import settings
from django.db import models
from django.db.models.signals import post_delete
from django.dispatch import receiver

DEFAULT_TITLE = "New chat"
GREETING_TEXT = "👋 Hi! I'm your AI assistant. How can I help you today?"


def title_from_prompt(prompt):
    """Short sidebar title from the first user message (max 5 words / 32 chars)."""
    compact = " ".join(prompt.split()[:5])
    if not compact:
        return DEFAULT_TITLE
    return compact if len(compact) <= 32 else compact[:29] + "..."


class Conversation(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="conversations"
    )
    title = models.CharField(max_length=255, default=DEFAULT_TITLE)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]

    def __str__(self):
        return f"{self.title} ({self.user.username})"


class Message(models.Model):
    ROLE_CHOICES = (
        ("user", "User"),
        ("assistant", "Assistant"),
        ("system", "System"),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    conversation = models.ForeignKey(
        Conversation, on_delete=models.CASCADE, related_name="messages"
    )
    role = models.CharField(max_length=10, choices=ROLE_CHOICES)
    content = models.TextField()
    # The model's visible "thinking" before it answered (reasoning models only).
    reasoning = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]

    def __str__(self):
        return f"[{self.role}] {self.content[:40]}"


def _attachment_path(instance, filename):
    # Random folder per file so names never collide and URLs aren't guessable.
    return f"attachments/{instance.user_id}/{uuid.uuid4().hex}/{filename}"


class Attachment(models.Model):
    """A file the user uploaded to send with a message (image or document).

    It is uploaded first (message=None) and linked to the user's Message when
    that message is sent over the WebSocket.
    """

    KIND_IMAGE = "image"
    KIND_DOCUMENT = "document"
    KIND_CHOICES = ((KIND_IMAGE, "Image"), (KIND_DOCUMENT, "Document"))

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="attachments"
    )
    message = models.ForeignKey(
        Message,
        on_delete=models.CASCADE,
        related_name="attachments",
        null=True,
        blank=True,
    )
    file = models.FileField(upload_to=_attachment_path, max_length=500)
    name = models.CharField(max_length=255)
    content_type = models.CharField(max_length=100)
    size = models.PositiveIntegerField()
    kind = models.CharField(max_length=10, choices=KIND_CHOICES)
    # Text pulled out of documents (PDF / text / code) so the model can read it.
    extracted_text = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]

    def __str__(self):
        return f"{self.name} ({self.kind})"


@receiver(post_delete, sender=Attachment)
def _delete_attachment_file(sender, instance, **kwargs):
    # Rows go away with their conversation (CASCADE); remove the file too.
    if instance.file:
        instance.file.delete(save=False)
