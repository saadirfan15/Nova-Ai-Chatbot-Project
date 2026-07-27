# 🤖 Nova AI Chatbot

A modern AI-powered chatbot application built with **Flutter** and **Django REST Framework**. The project provides secure user authentication, real-time messaging using WebSockets, and a clean, responsive mobile interface.

---

## 📌 Features

- 🔐 User Registration & Login
- 🔑 JWT Authentication
- 💬 Real-time Chat using WebSockets
- 📱 Cross-platform Flutter Application
- 🌐 RESTful API Integration
- 📂 Conversation Management
- 📜 Chat History
- 🎨 Modern Responsive UI
- 🔒 Secure Token Storage
- ⚡ Fast & Lightweight Architecture

---

## 🛠 Tech Stack

### Frontend

- Flutter
- Dart
- Provider (State Management)
- HTTP Package
- WebSocket

### Backend

- Python
- Django
- Django REST Framework
- Django Channels
- JWT Authentication
- SQLite

---

# 📁 Project Structure

```text
Nova-AI-Chatbot-Project/
│
├── backend/
│   ├── apps/
│   │   ├── accounts/
│   │   ├── chat/
│   │   └── __init__.py
│   │
│   ├── config/
│   │   ├── settings.py
│   │   ├── urls.py
│   │   ├── asgi.py
│   │   └── wsgi.py
│   │
│   ├── scripts/
│   │   ├── test_create_conversation.py
│   │   └── test_ws_flow.py
│   │
│   ├── manage.py
│   ├── requirements.txt
│   └── db.sqlite3
│
├── flutter_application_1/
│   ├── android/
│   ├── ios/
│   ├── linux/
│   ├── macos/
│   ├── windows/
│   ├── web/
│   │
│   ├── Assets/
│   │   └── images/
│   │
│   ├── lib/
│   │   ├── config/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   ├── services/
│   │   ├── utils/
│   │   ├── widgets/
│   │   └── main.dart
│   │
│   ├── test/
│   ├── pubspec.yaml
│   └── README.md
│
├── .gitignore
└── README.md
```

---

# 🚀 Getting Started

## 1️⃣ Clone Repository

```bash
git clone https://github.com/saadirfan15/Nova-AI-Chatbot-Project.git

cd Nova-AI-Chatbot-Project
```

---

# ⚙ Backend Setup (Django)

### Create Virtual Environment

```bash
python -m venv venv
```

### Activate Virtual Environment

Windows

```bash
venv\Scripts\activate
```

Linux / macOS

```bash
source venv/bin/activate
```

### Install Dependencies

```bash
pip install -r backend/requirements.txt
```

### Run Migrations

```bash
cd backend

python manage.py migrate
```

### Start Backend Server

```bash
python manage.py runserver
```

Backend will run at

```
http://127.0.0.1:8000/
```

---

# 📱 Flutter Setup

Navigate to Flutter project

```bash
cd flutter_application_1
```

Install packages

```bash
flutter pub get
```

Run the application

```bash
flutter run
```

---

# 🔑 Authentication

The project uses **JWT Authentication**.

Endpoints include:

- User Registration
- User Login
- Refresh Token
- Protected APIs

---

# 💬 Real-Time Chat

The application supports:

- WebSocket Connection
- Live Messaging
- Conversation Management
- Instant Updates

---

# 📦 API Features

- Register User
- Login User
- Refresh JWT Token
- Create Conversation
- Send Messages
- Fetch Chat History

---

# 📸 Screenshots

Add screenshots here.

Example:

```
assets/screenshots/login.png
assets/screenshots/chat.png
assets/screenshots/register.png
```

---

# 📈 Future Improvements

- AI Integration (OpenAI / Gemini)
- Voice Chat
- File Sharing
- Push Notifications
- Group Chats
- Dark Mode
- User Profile Management
- Message Search

---

# 👨‍💻 Author

**Saad Irfan**

GitHub: https://github.com/saadirfan15

LinkedIn: in/saad-irfan-9b5205304

---

# ⭐ Support

If you found this project helpful, consider giving it a ⭐ on GitHub.