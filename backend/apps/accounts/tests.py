from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase

User = get_user_model()


class AuthApiTests(APITestCase):
    def test_register_returns_tokens(self):
        resp = self.client.post(
            "/api/auth/register/",
            {"username": "alice", "email": "alice@example.com", "password": "S3cure!pass"},
            format="json",
        )
        self.assertEqual(resp.status_code, 201)
        self.assertIn("access", resp.data)
        self.assertIn("refresh", resp.data)
        self.assertEqual(resp.data["user"]["username"], "alice")

    def test_register_rejects_duplicate_email(self):
        User.objects.create_user("bob", "dup@example.com", "S3cure!pass")
        resp = self.client.post(
            "/api/auth/register/",
            {"username": "bob2", "email": "dup@example.com", "password": "S3cure!pass"},
            format="json",
        )
        self.assertEqual(resp.status_code, 400)

    def test_login_refresh_and_me(self):
        User.objects.create_user("carol", "carol@example.com", "S3cure!pass")
        resp = self.client.post(
            "/api/auth/login/", {"username": "carol", "password": "S3cure!pass"}, format="json"
        )
        self.assertEqual(resp.status_code, 200)

        refreshed = self.client.post(
            "/api/auth/refresh/", {"refresh": resp.data["refresh"]}, format="json"
        )
        self.assertEqual(refreshed.status_code, 200)
        self.assertIn("access", refreshed.data)

        access = refreshed.data["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
        me = self.client.get("/api/auth/me/")
        self.assertEqual(me.status_code, 200)
        self.assertEqual(me.data["username"], "carol")

    def test_me_requires_auth(self):
        self.assertEqual(self.client.get("/api/auth/me/").status_code, 401)
