# ==============================================================================
# Dockerfile Unificado de Producción (Frontend React PWA + Backend FastAPI + TTS)
# Diseñado para despliegue 1-Click en Render.com (https://inventariogta.onrender.com)
# Soporta tanto carpetas backend/frontend como archivo empaquetado app_bundle.tar.gz
# ==============================================================================

# ─────────────────────────────────────────
# Stage 0: Desempaquetar código fuente
# ─────────────────────────────────────────
FROM alpine:3.20 AS unpacker
WORKDIR /src
COPY . .
RUN if [ -f app_bundle.tar.gz ]; then tar -xzf app_bundle.tar.gz; fi

# ─────────────────────────────────────────
# Stage 1: Compilar Frontend React + Vite
# ─────────────────────────────────────────
FROM node:20-alpine AS frontend-builder

WORKDIR /frontend

COPY --from=unpacker /src/frontend/package.json /src/frontend/package-lock.json* ./
RUN npm install

COPY --from=unpacker /src/frontend/ ./
RUN npm run build

# ─────────────────────────────────────────
# Stage 2: Backend FastAPI + Static SPA
# ─────────────────────────────────────────
FROM python:3.12-slim AS production

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    STATIC_DIST_DIR=/app/static_dist

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=unpacker /src/backend/requirements.txt ./requirements.txt
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copiar código del backend (incluye initial_seed_data.json con los 139 equipos)
COPY --from=unpacker /src/backend/ ./

# Copiar el frontend compilado desde Stage 1
COPY --from=frontend-builder /frontend/dist /app/static_dist

# Directorio de uploads para documentos escaneados y evidencias
RUN mkdir -p /app/uploads && chmod 777 /app/uploads

EXPOSE 8000

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
