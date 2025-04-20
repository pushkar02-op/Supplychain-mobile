FROM python:3.11

WORKDIR /app
COPY ./app /app
COPY requirements.txt /app
COPY alembic.ini /app/alembic.ini
COPY alembic /app/alembic
COPY wait-for-db.sh /app/wait-for-db.sh 

RUN apt-get update && apt-get install -y netcat-openbsd && \
    pip install --upgrade pip && \
    pip install -r requirements.txt
RUN chmod +x wait-for-db.sh

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
