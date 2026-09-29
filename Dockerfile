# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (Production-ready Multi-stage Dockerfile)
# ═══════════════════════════════════════════════════════════════════

# Stage 1: Builder
FROM python:3.11-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --default-timeout=1000 --retries=10 --prefix=/install -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Tạo user thường để tránh chạy bằng root
RUN useradd --create-home --uid 10001 appuser

# Copy mã nguồn ứng dụng (sau pip install để tận dụng cache)
COPY . .

# Phân quyền cho appuser
RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request, os; port = os.getenv('PORT', '8000'); urllib.request.urlopen(f'http://127.0.0.1:{port}/health').read()" || exit 1

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
