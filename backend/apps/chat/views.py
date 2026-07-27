from django.db import transaction
from rest_framework import generics, permissions, status
from rest_framework.response import Response

from .models import Conversation, Message
from .serializers import ConversationSerializer, ConversationDetailSerializer


GREETING_TEXT = "👋 Hi! I'm your AI assistant. How can I help you today?"


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
            print(f"DEBUG: Conversation created: {conv.id}")
            # Create a one-time assistant greeting for brand-new conversations
            greeting = Message.objects.create(conversation=conv, role="assistant", content=GREETING_TEXT)
            print(f"DEBUG: Greeting created: id={greeting.id} content={greeting.content!r}")

        # Return full conversation detail (including messages) so frontends
        # can display the greeting immediately without a second fetch.
        detail_serializer = ConversationDetailSerializer(conv)
        serialized = detail_serializer.data
        print(f"DEBUG: Serialized response about to be returned: {serialized}")
        # Extra check: does serialized messages include the greeting?
        has_greeting = any(m.get("role") == "assistant" and m.get("content") == GREETING_TEXT for m in serialized.get("messages", []))
        print(f"DEBUG: Serialized contains greeting: {has_greeting}")
        headers = self.get_success_headers(serialized)
        return Response(serialized, status=status.HTTP_201_CREATED, headers=headers)


class ConversationDetailView(generics.RetrieveDestroyAPIView):
    """Fetch full message history for one conversation, or delete it."""
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ConversationDetailSerializer
    lookup_field = "id"

    def get_queryset(self):
        return Conversation.objects.filter(user=self.request.user)
