"""
Custom Channels middleware to authenticate WebSocket connections using
a JWT access token passed as a query param: ws://.../ws/chat/?token=<access>
"""
from urllib.parse import parse_qs

from channels.db import database_sync_to_async
from channels.middleware import BaseMiddleware
from django.conf import settings
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.tokens import AccessToken


@database_sync_to_async
def get_user_from_token(token):
    from django.contrib.auth import get_user_model

    User = get_user_model()

    try:
        print("=" * 60)
        print("SECRET_KEY:", settings.SECRET_KEY)
        print("JWT TOKEN RECEIVED:")
        print(token)

        validated_token = AccessToken(token)

        print("JWT PAYLOAD:")
        print(validated_token.payload)

        user_id = validated_token["user_id"]
        print("USER ID:", user_id)

        user = User.objects.get(id=user_id)

        print("AUTHENTICATED USER:", user)
        print("=" * 60)

        return user

    except (InvalidToken, TokenError, User.DoesNotExist, KeyError) as e:
        print("=" * 60)
        print("SECRET_KEY:", settings.SECRET_KEY)
        print("JWT AUTH FAILED:")
        print(type(e).__name__, e)
        print("TOKEN:", token)
        print("=" * 60)
        return AnonymousUser()


class JWTAuthMiddleware(BaseMiddleware):
    async def __call__(self, scope, receive, send):
        query_string = parse_qs(scope["query_string"].decode())
        print("QUERY STRING:", query_string)

        token = query_string.get("token", [None])[0]

        if token:
            print("TOKEN FOUND")
            scope["user"] = await get_user_from_token(token)
            print(
                "SCOPE USER:",
                scope["user"],
                "AUTH:",
                getattr(scope["user"], "is_authenticated", False),
            )
        else:
            print("NO TOKEN FOUND")
            scope["user"] = AnonymousUser()

        return await super().__call__(scope, receive, send)


def JWTAuthMiddlewareStack(inner):
    return JWTAuthMiddleware(inner)