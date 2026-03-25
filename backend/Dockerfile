FROM python:3.11-slim

WORKDIR /usr/src/awattprice

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV POETRY_VERSION=1.8.3

RUN apt-get update \
    && apt-get install -y --no-install-recommends cron \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir "poetry==$POETRY_VERSION"

COPY pyproject.toml poetry.lock ./

RUN poetry config virtualenvs.create false \
    && poetry install --only main --no-interaction --no-ansi --no-root

COPY src ./src

RUN poetry install --only main --no-interaction --no-ansi

RUN printf 'SHELL=/bin/sh\nPATH=%s\n*/10 * * * * root python /usr/src/awattprice/src/awattprice_notifications/price_below/service.py\n' "$PATH" > /etc/crontab

CMD ["sh", "-c", "cron && exec gunicorn --workers 1 --access-logfile - --bind unix:/etc/awattprice/socket/awattprice.sock -k uvicorn.workers.UvicornWorker awattprice.api:app"]
