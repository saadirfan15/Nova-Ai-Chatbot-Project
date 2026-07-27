# import os

# from django.core.asgi import get_asgi_application

# os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

# # Initialize Django ASGI application early to ensure the AppRegistry
# # is populated before importing code that may import ORM models.
# django_asgi_app = get_asgi_application()

# from channels.routing import ProtocolTypeRouter, URLRouter  # noqa: E402
# from channels.auth import AuthMiddlewareStack  # noqa: E402
# from apps.chat.middleware import JWTAuthMiddlewareStack  # noqa: E402
# import apps.chat.routing  # noqa: E402

# application = ProtocolTypeRouter(
#     {
#         "http": django_asgi_app,
#         "websocket": JWTAuthMiddlewareStack(
#             URLRouter(apps.chat.routing.websocket_urlpatterns)
#         ),
#     }
# )
import os

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

from django.core.asgi import get_asgi_application

django_asgi_app = get_asgi_application()

from channels.routing import ProtocolTypeRouter, URLRouter
from apps.chat.middleware import JWTAuthMiddlewareStack
from apps.chat.routing import websocket_urlpatterns


application = ProtocolTypeRouter(
    {
        "http": django_asgi_app,
        "websocket": JWTAuthMiddlewareStack(
            URLRouter(websocket_urlpatterns)
        ),
    }
)
