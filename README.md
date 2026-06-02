# MIT - Billing Admin

## Running the Backend

### Prerequisites
- Python 3.8+
- PostgreSQL (via Supabase)

## Dart SDK Setup

### macOS with Homebrew

```bash
brew tap dart-lang/dart
brew install dart
```

If Homebrew is already installed, make sure its bin directory is on your PATH so commands like dart, dart run, and dart format work from any shell session.

To upgrade later:

```bash
brew upgrade dart
```

### Windows and Linux

Use the official Dart installation instructions for your platform if you are not on macOS with Homebrew.

## Flutter SDK Setup

### macOS with Homebrew

```bash
brew install flutter
```

If Flutter is already installed, make sure the Homebrew bin directory is on your PATH so `flutter`, `flutter pub`, and `flutter run` are available in every shell session.

To verify the install:

```bash
flutter --version
```

### Install Client Dependencies

```bash
cd client
flutter pub get
```

### Setup & Run

```bash
cd backend

# Option 1: Quick setup script
chmod +x start.sh && ./start.sh

# Option 2: Manual setup
python3 -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Copy and fill in env vars
cp .env.example .env            # Update DATABASE_URL in .env

# Init DB and start server
python -m app.init_db
uvicorn app.main:app --reload
```

API runs at `http://localhost:8000`
Docs at `http://localhost:8000/docs`

Default credentials: `admin` / `admin`
