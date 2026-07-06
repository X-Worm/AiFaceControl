# AI Face Control 🚪🤖

A voice-AI **bouncer**. Knock on the door of the *AI Addicts Club*, and **Rex** —
a robot bouncer — sizes you up in real time: he asks who you are and hits you with
one unexpected screening question to check you're genuinely *one of us*. Talk your
way past him and the door swings open: **"Welcome to the club, buddy."**

Built with [Pipecat](https://github.com/pipecat-ai/pipecat) on Google's **Gemini
Live** API — a single speech-to-speech model, so Rex hears and speaks directly
(no separate STT/LLM/TTS). Every guest he lets in gets logged to **Telegram**.

> A small, honest demo of a real production pattern: a low-latency voice agent
> with tool-calling, business logic, a live web client, and an outbound
> notification — the exact shape of an appointment-booking / reception / lead-qual
> voice bot, wrapped in a fun persona. **English only.**

## How it works

```
Browser (mic + door UI)  ◄── WebRTC (Daily) ──►  Pipecat bot  ◄── WebSocket ──►  Gemini Live
                                                      │
                                                      └──► Telegram Bot API  (guest logbook)
```

- **`bot.py`** — the voice brain. Rex's persona + screening questions, the
  `grant_entry` tool (opens the door, DMs you the guest over Telegram, and sends
  the frontend an RTVI `door-open` message), and light rate limiting.
- **`client/index.html`** — a self-contained page (no build step): neon sign, a
  shut door, and a **Knock** button. Connects to the bot over Daily using the
  Pipecat JS client. When Rex grants entry, the door animates open and reveals
  this repo's link.

## Run it locally

You need a Google AI key (Gemini Live), a Daily key, and a Telegram bot.

```bash
# 1. Configure
cp .env.example .env        # fill in the keys (see below)
uv sync

# 2. Start the bot (Daily transport)
uv run bot.py -t daily

# 3. Serve the client (separate terminal)
cd client
python -m http.server 8000
```

Open **http://localhost:8000**, click **Knock**, allow your microphone, and talk
your way in.

> Prefer no Daily account? `uv run bot.py` (no flag) runs the bot on Pipecat's
> built-in SmallWebRTC client at http://localhost:7860 — handy for a quick voice
> test without the custom page.

## Run with Docker

The stack is two containers — the bot and a tiny nginx that serves the door page
and proxies `/start` to the bot, so the page and the API share one origin:

```bash
cp .env.example .env        # fill in the keys
docker compose up --build
```

Open **http://localhost:8080**. In production, put this behind a TLS-terminating
reverse proxy (the browser only grants microphone access over HTTPS).

### Environment variables

| Var | What | Where |
|---|---|---|
| `GOOGLE_API_KEY` | Gemini Live (speech-to-speech) | [aistudio.google.com](https://aistudio.google.com) |
| `DAILY_API_KEY` | WebRTC transport (needs a payment method on file, even for free minutes) | [dashboard.daily.co](https://dashboard.daily.co) |
| `TELEGRAM_BOT_TOKEN` | Guest logbook bot | [@BotFather](https://t.me/BotFather) |
| `TELEGRAM_CHAT_ID` | Where to DM the logbook | message your bot, then read `https://api.telegram.org/bot<TOKEN>/getUpdates` |
| `GEMINI_VOICE` | Prebuilt voice: Aoede, Charon, Fenrir, Kore, Puck | optional (default `Fenrir`) |
| `GEMINI_MODEL` | S2S model | optional |
| `MAX_SESSION_SECONDS` / `MAX_SESSIONS_PER_DAY` | Rate limits | optional |

Then set two constants at the top of `client/index.html`: `BOT_START_URL`
(local `http://localhost:7860/start`, prod `https://your-domain/start`) and
`GITHUB_URL`.

## How the door opens

When Rex decides you're in, the bot calls `grant_entry`, which sends an RTVI
**server message** `{ "type": "door-open" }`. The page listens via
`onServerMessage` and plays the animation — so the door opens exactly when the
bouncer says so, not on a timer.

## Rate limiting

`bot.py` enforces a per-session time cap (`MAX_SESSION_SECONDS`, default 180s) and
a soft daily guest cap (`MAX_SESSIONS_PER_DAY`, default 50). For a public deploy,
put the real per-IP / daily gate in the reverse proxy in front of the bot, before
a Gemini session is ever opened.

## Deploy notes

- **Docker**: `Dockerfile` builds the bot; `docker-compose.yml` runs bot + web.
  Point your edge reverse proxy at the `web` container (or its published `:8080`).
- Transport is **Daily** in production too (no coturn, no NAT tuning) — WebRTC
  media flows browser ↔ Daily cloud ↔ bot, so only a short `POST /start` ever
  hits your origin. That makes it safe to run behind Cloudflare or any CDN. Daily
  free tier: 10,000 participant-min/month, then $0.004/participant-min.
- Serve the page over **HTTPS** (nginx/Caddy + Let's Encrypt) — browsers only
  grant microphone access on a secure origin.
- Put the real per-IP / daily gate in the edge proxy in front of `/start`, before
  a Gemini session is ever opened (behind Cloudflare, key it on `CF-Connecting-IP`).

## Tech

Pipecat · Google Gemini Live (speech-to-speech) · Daily WebRTC · Telegram Bot API
· `@pipecat-ai/client-js` + `@pipecat-ai/daily-transport` (vanilla JS, no build).
