from django.urls import path

from .views import (
    AttachmentFileView,
    AttachmentUploadView,
    ConversationDetailView,
    ConversationListView,
)

urlpatterns = [
    path("conversations/", ConversationListView.as_view(), name="conversation-list"),
    path(
        "conversations/<uuid:id>/",
        ConversationDetailView.as_view(),
        name="conversation-detail",
    ),
    path("attachments/", AttachmentUploadView.as_view(), name="attachment-upload"),
    path(
        "attachments/<uuid:id>/file/",
        AttachmentFileView.as_view(),
        name="attachment-file",
    ),
]
