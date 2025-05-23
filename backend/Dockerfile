# backend/Dockerfile
FROM python:3.11-slim AS base

# 1. Set workdir
WORKDIR /app

# 2. Install OS deps
RUN apt-get update \
    && apt-get install -y --no-install-recommends netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# 3. Copy only requirements first (for better cache)
COPY requirements.txt alembic.ini wait-for-db.sh /app/
COPY alembic /app/alembic

# 4. Install Python deps
RUN pip install --upgrade pip \
    && pip install -r requirements.txt \
    && chmod +x wait-for-db.sh

# 5. Copy source
COPY app /app/app

# 6. Default command
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
