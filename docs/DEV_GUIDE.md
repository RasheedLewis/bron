# Bron Developer Guide

This guide walks you through setting up and running the Bron app locally for development.

---

## Prerequisites

### Required
- **macOS** 14.0+ (Sonoma or later)
- **Xcode** 15.0+
- **Python** 3.10+
- **Anthropic API Key** — Get one at [console.anthropic.com](https://console.anthropic.com)

### Optional (for OAuth)
- **Google Cloud Console** account for Gmail/Calendar integration
- **Claude CLI** for Agent SDK features (`npm install -g @anthropic-ai/claude-cli`)

---

## Quick Start

```bash
# Clone the repo
git clone https://github.com/your-org/bron.git
cd bron

# Start the server
cd server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp env.example .env
# Edit .env and add your ANTHROPIC_API_KEY
uvicorn app.main:app --reload

# In another terminal, open Xcode
open ios/Bron/Bron.xcodeproj
# Press Cmd+R to run on simulator
```

---

## Server Setup (Python/FastAPI)

### 1. Create Virtual Environment

```bash
cd server
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Configure Environment

```bash
cp env.example .env
```

Edit `.env` with your settings:

```bash
# Required
ANTHROPIC_API_KEY=sk-ant-xxxxx

# Optional: OAuth (for Gmail, Calendar, etc.)
GOOGLE_CLIENT_ID=xxxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=xxxxx
```

### 4. Run the Server

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The API is now available at `http://localhost:8000`.

### 5. Verify It's Working

```bash
curl http://localhost:8000/api/v1/brons
# Should return: {"brons": []}
```

### API Documentation

Once running, visit:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

---

## iOS Setup (SwiftUI)

### 1. Open the Project

```bash
open ios/Bron/Bron.xcodeproj
```

### 2. Configure the Server URL

The app connects to `http://localhost:8000` by default. This works for Simulator but not physical devices.

**For physical device testing**, update `APIClient.swift`:

```swift
// Change from:
private let baseURL = "http://localhost:8000/api/v1"

// To your Mac's local IP:
private let baseURL = "http://192.168.x.x:8000/api/v1"
```

Find your IP with: `ifconfig | grep "inet " | grep -v 127.0.0.1`

### 3. Add Custom Fonts (Already Done)

The app uses **Bebas Neue** and **IBM Plex Sans**. Font files are in `ios/Bron/Bron/Resources/`.

If fonts don't appear:
1. Select target → Build Phases → Copy Bundle Resources
2. Verify all `.ttf` files are listed
3. Select target → Info tab → Add `Fonts provided by application`
4. Add each font filename (e.g., `BebasNeue-Regular.ttf`)

### 4. Run the App

1. Select a Simulator (iPhone 15 Pro recommended)
2. Press `Cmd + R` to build and run
3. The app should launch and connect to your local server

---

## Database

### Location
The SQLite database is created at `server/bron.db` on first run.

### Reset Database
To start fresh, delete the database and restart the server:

```bash
rm server/bron.db
# Restart uvicorn - tables are recreated automatically
```

### View Database
```bash
sqlite3 server/bron.db
.tables
SELECT * FROM brons;
.quit
```

---

## OAuth Setup (Optional)

For Gmail, Google Calendar, and other OAuth integrations:

### Google OAuth

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Create a new project or select existing
3. Enable required APIs:
   - Gmail API
   - Google Calendar API
4. Create OAuth 2.0 Client ID:
   - Application type: **iOS** or **Web**
   - Authorized redirect URIs: `bron://oauth/callback/google`
5. Copy Client ID and Secret to `.env`:

```bash
GOOGLE_CLIENT_ID=xxxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=xxxxx
```

### iOS URL Scheme

In Xcode:
1. Select your target → Info tab
2. Expand "URL Types"
3. Click + and add:
   - Identifier: `com.bron.oauth`
   - URL Schemes: `bron`

---

## Claude Agent SDK (Optional)

For enhanced agent capabilities:

### 1. Install Claude CLI

```bash
npm install -g @anthropic-ai/claude-cli
claude login
```

### 2. Verify Authentication

```bash
claude --version
```

The server automatically detects if the SDK is available and uses it when possible.

---

## Project Structure

```
bron/
├── docs/                    # Documentation
│   ├── PRD.md              # Product requirements
│   ├── DESIGN.md           # Design system
│   ├── VOICE.md            # Brand voice guidelines
│   ├── UI.md               # UI component philosophy
│   ├── CHAT_LAYOUT.md      # Chat interface spec
│   └── DEV_GUIDE.md        # This file
│
├── server/                  # Python backend
│   ├── app/
│   │   ├── api/            # FastAPI endpoints
│   │   ├── core/           # Config, settings
│   │   ├── db/             # Database session
│   │   ├── models/         # SQLAlchemy models
│   │   ├── schemas/        # Pydantic schemas
│   │   └── services/       # Business logic (Claude, orchestrator)
│   ├── requirements.txt
│   ├── env.example
│   └── bron.db             # SQLite database (created on run)
│
└── ios/Bron/               # iOS app
    └── Bron/
        ├── App/            # App entry, state
        ├── Models/         # Swift data models
        ├── Views/          # SwiftUI views
        ├── Services/       # API, persistence, auth
        ├── Theme/          # Colors, typography, layout
        └── Resources/      # Fonts, assets
```

---

## Common Issues

### "Connection refused" on iOS

**Cause**: Server isn't running or wrong URL.

**Fix**:
1. Ensure server is running: `uvicorn app.main:app --reload`
2. Check `APIClient.swift` uses correct URL
3. For Simulator, use `localhost`. For device, use your Mac's IP.

### "Expected date string to be ISO8601-formatted"

**Cause**: Date format mismatch between Python and Swift.

**Fix**: Already handled in `APIClient.swift` with custom date decoder. If you see this, ensure you're using the latest code.

### Fonts not rendering

**Cause**: Fonts not properly added to Xcode project.

**Fix**:
1. Verify `.ttf` files are in Copy Bundle Resources
2. Add font names to Info.plist under `UIAppFonts`
3. Clean build folder: `Cmd + Shift + K`

### Claude returns generic responses

**Cause**: API key not set or invalid.

**Fix**:
1. Check `.env` has valid `ANTHROPIC_API_KEY`
2. Restart server after changing `.env`
3. Check server logs for API errors

### "Overloaded" errors from Claude

**Cause**: Anthropic API is temporarily overloaded.

**Fix**: The server has retry logic built in. Wait a few seconds and try again.

### Database schema errors

**Cause**: Database schema is out of sync with models.

**Fix**:
```bash
rm server/bron.db
# Restart server
```

---

## Development Tips

### Hot Reload
- **Server**: `--reload` flag auto-restarts on file changes
- **iOS**: SwiftUI previews update automatically; full builds need `Cmd + R`

### Debugging

**Server logs**: Check terminal running uvicorn for detailed logs with 🔍 emoji markers.

**iOS logs**: Use Xcode console or add breakpoints.

**Network**: Use Proxyman or Charles Proxy to inspect API traffic.

### Testing Claude Prompts

Test Claude responses directly:

```bash
curl -X POST http://localhost:8000/api/v1/chat/send \
  -H "Content-Type: application/json" \
  -d '{"bron_id": "YOUR_BRON_ID", "message": "Help me plan a trip"}'
```

---

## API Endpoints Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/brons` | List all Brons |
| POST | `/api/v1/brons` | Create a Bron |
| GET | `/api/v1/brons/{id}` | Get Bron details |
| DELETE | `/api/v1/brons/{id}` | Delete a Bron |
| GET | `/api/v1/chat/{bron_id}/history` | Get chat messages |
| POST | `/api/v1/chat/send` | Send a message |
| POST | `/api/v1/chat/ui-recipe/submit` | Submit form data |
| POST | `/api/v1/oauth/start` | Start OAuth flow |
| POST | `/api/v1/oauth/callback` | OAuth token exchange |

---

## Contributing

1. Create a feature branch: `git checkout -b feature/my-feature`
2. Make changes and test locally
3. Ensure no linter errors in Swift or Python
4. Submit a pull request

---

## Need Help?

- Check existing issues on GitHub
- Review the docs in `/docs`
- Server logs often contain detailed error info

