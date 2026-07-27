import os
import sys

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
import django
django.setup()

from django.contrib.auth import get_user_model
from rest_framework.test import APIClient

User = get_user_model()
# Create or get a test user
user, created = User.objects.get_or_create(username='test_runner')
if created:
    user.set_password('runnerpass')
    user.save()
    print('Created user test_runner')

client = APIClient()
client.force_authenticate(user=user)

print('Running POST to create conversation...')
resp = client.post('/api/chat/conversations/')
print('Response status:', resp.status_code)
try:
    print('Response json:', resp.json())
except Exception as e:
    print('Failed to decode JSON response:', e)
    print('Response content:', resp.content)

# Show messages in DB for the created conversation if any
from apps.chat.models import Conversation, Message
conv_id = None
if resp.status_code in (200, 201):
    data = resp.json()
    conv_id = data.get('id')

if conv_id:
    try:
        conv = Conversation.objects.get(id=conv_id)
        msgs = list(conv.messages.all())
        print('DB messages for conversation:', [(m.id, m.role, m.content) for m in msgs])
    except Exception as e:
        print('Error fetching conversation messages from DB:', e)
else:
    print('No conversation id returned')

print('Test script finished')
