FROM python:3.11-slim

WORKDIR /usr/src/awattprice

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PATH="/usr/src/awattprice/.venv/bin:$PATH"

RUN pip install --no-cache-dir "uv>=0.11.1,<0.12.0"

COPY pyproject.toml uv.lock README.md ./

RUN uv sync --locked --no-dev --no-install-project

COPY src ./src

RUN uv sync --locked --no-dev --no-editable

CMD ["gunicorn", "--workers", "1", "--access-logfile", "-", "--bind", "unix:/etc/awattprice/socket/awattprice.sock", "-k", "uvicorn.workers.UvicornWorker", "awattprice.api:app"]
