import os

from django.db import transaction
from django.http import FileResponse
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from .attachments import UnsupportedFile, classify, extract_text
from .models import GREETING_TEXT, Attachment, Conversation, Message
from .serializers import (
    AttachmentSerializer,
    ConversationDetailSerializer,
    ConversationSerializer,
)


class ConversationListView(generics.ListCreateAPIView):
    """List all conversations for the logged-in user (sidebar history).

    Also supports creating a brand-new conversation. When created via REST
    (e.g. when the frontend starts a new chat), the view will insert a
    single assistant greeting message so the user sees an initial welcome
    immediately.
    """
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ConversationSerializer

    def get_queryset(self):
        return Conversation.objects.filter(user=self.request.user)

    def create(self, request, *args, **kwargs):
        with transaction.atomic():
            conv = Conversation.objects.create(user=request.user)
            Message.objects.create(conversation=conv, role="assistant", content=GREETING_TEXT)

        # Return full conversation detail (including messages) so frontends
        # can display the greeting immediately without a second fetch.
        serialized = ConversationDetailSerializer(conv).data
        headers = self.get_success_headers(serialized)
        return Response(serialized, status=status.HTTP_201_CREATED, headers=headers)


class ConversationDetailView(generics.RetrieveDestroyAPIView):
    """Fetch full message history for one conversation, or delete it."""
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ConversationDetailSerializer
    lookup_field = "id"

    def get_queryset(self):
        return Conversation.objects.filter(user=self.request.user)


class AttachmentUploadView(APIView):
    """Upload one file (multipart field "file") to attach to the next message."""

    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser]

    def post(self, request):
        upload = request.FILES.get("file")
        if upload is None:
            return Response(
                {"detail": "No file was uploaded."}, status=status.HTTP_400_BAD_REQUEST
            )
        try:
            kind, content_type = classify(upload.name, upload.size)
        except UnsupportedFile as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        attachment = Attachment.objects.create(
            user=request.user,
            file=upload,
            name=os.path.basename(upload.name)[:255],
            content_type=content_type,
            size=upload.size,
            kind=kind,
            extracted_text=(
                extract_text(upload, upload.name)
                if kind == Attachment.KIND_DOCUMENT
                else ""
            ),
        )
        return Response(
            AttachmentSerializer(attachment).data, status=status.HTTP_201_CREATED
        )


class AttachmentFileView(APIView):
    """Download an attachment's file (owner only)."""

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, id):
        attachment = get_object_or_404(Attachment, id=id, user=request.user)
        return FileResponse(
            attachment.file.open("rb"),
            content_type=attachment.content_type,
            filename=attachment.name,
        )
