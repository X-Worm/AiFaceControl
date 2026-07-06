# syntax=docker/dockerfile:1
FROM python:3.12-slim

# uv — fast, reproducible installs straight from uv.lock
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# onnxruntime (Silero VAD) needs libgomp1; ca-certificates for TLS to Gemini/Daily/Telegram
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install dependencies first (cached layer). The project is a plain script, not a
# package, so --no-install-project skips needing a build backend.
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

COPY bot.py ./

ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 7860
CMD ["python", "bot.py", "-t", "daily", "--host", "0.0.0.0", "--port", "7860"]
