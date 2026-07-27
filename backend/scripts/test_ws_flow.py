import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
import django
django.setup()

from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from apps.chat.models import Conversation, Message

User = get_user_model()
user, _ = User.objects.get_or_create(username='test_runner')
client = APIClient()
client.force_authenticate(user=user)

print('Creating conversation via REST...')
resp = client.post('/api/chat/conversations/')
print('Status', resp.status_code)
data = resp.json()
conv_id = data['id']
print('Conversation created:', conv_id)

conv = Conversation.objects.get(id=conv_id)
print('Messages after REST create:', [(m.id, m.role, m.content) for m in conv.messages.all()])

# Simulate websocket saving a user message
print('Simulating WS save_message...')
user_msg = Message.objects.create(conversation=conv, role='user', content='Hello from WS')
print('User message created:', user_msg.id)

conv = Conversation.objects.get(id=conv_id)
print('Messages after WS save:', [(m.id, m.role, m.content) for m in conv.messages.order_by('created_at')])

# Ensure greeting unchanged
greetings = [m for m in conv.messages.all() if m.role == 'assistant' and m.content.startswith('👋')]
print('Assistant greeting messages found:', [(g.id, g.content) for g in greetings])
print('Test WS flow finished')
