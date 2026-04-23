# Ollama Usage Dashboard

A local dashboard to track Ollama API usage across multiple accounts, with automatic snapshot保存 before fallback/reset.

## Access

**URL:** `http://localhost:3099`

**Password:** `ghp.2026`

## Features

- 📊 Real-time usage tracking per account (prompt tokens, completion tokens, requests)
- 🔐 Password-protected dashboard
- 📸 Automatic snapshots before account reset
- 📜 Historical snapshot inspection
- 🔄 Manual snapshot and reset controls

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/usage` | GET | Get current usage for all accounts |
| `/api/snapshots` | GET | Get all saved snapshots |
| `/api/snapshot` | POST | Manually take a snapshot |
| `/api/reset` | POST | Reset an account (saves snapshot first) |
| `/api/track` | POST | Track Ollama API response (for integration) |

### API Examples

```bash
# Get usage
curl "http://localhost:3099/api/usage?key=ghp.2026"

# Get snapshots
curl "http://localhost:3099/api/snapshots?key=ghp.2026"

# Manual snapshot
curl -X POST "http://localhost:3099/api/snapshot?key=ghp.2026" \
  -H "Content-Type: application/json" \
  -d '{"account":"ollama_account1","reason":"manual"}'

# Reset account (saves snapshot first)
curl -X POST "http://localhost:3099/api/reset?key=ghp.2026" \
  -H "Content-Type: application/json" \
  -d '{"account":"ollama_account1"}'
```

## How It Works

1. Each account (ollama_account1, ollama_account2) has usage counters
2. When you reset an account, it saves a "pre-reset" snapshot
3. Snapshots are stored in `usage-data/snapshots.json`
4. Use snapshots to analyze percentage usage before quota exhaustion

## Data Storage

```
workspace/
├── usage-data/
│   ├── usage.json       # Current usage counters
│   └── snapshots.json   # Historical snapshots
└── usage-dashboard.html # Dashboard UI
```

## Server Management

```bash
# Start server
node ~/workspace/scripts/usage-tracker.js

# The server runs on port 3099
```

## Integration with OpenClaw (Manual Tracking)

Since OpenClaw handles Ollama API calls internally, usage tracking requires manual updates or webhook integration. To manually log usage:

```bash
# After each API call, extract tokens from Ollama response and POST to tracker:
curl -X POST "http://localhost:3099/api/track?key=ghp.2026" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "minimax-m2.7:cloud",
    "prompt_eval_count": 150,
    "eval_count": 300
  }'
```

## Future Integration Ideas

- [ ] OpenClaw plugin to automatically track API calls
- [ ] Proxy middleware to intercept Ollama requests
- [ ] Automatic fallback detection and snapshot
- [ ] Export to CSV/JSON for analysis
