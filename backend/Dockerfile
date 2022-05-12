# syntax:docker/dockerfile:1

FROM python:3.10
SHELL ["/bin/bash", "-c"]

WORKDIR /usr/src/awattprice

RUN mkdir /etc/awattprice/ && mkdir /etc/awattprice/socket/

# Install poetry.
RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="/root/.local/bin:$PATH"

# Setup virtualenv (see https://pythonspeed.com/articles/activate-virtualenv-dockerfile/).
RUN pip install virtualenv==20.14.1
ENV VIRTUAL_ENV=/opt/venvs/awattprice
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Install dependencies.
COPY pyproject.toml .
COPY poetry.lock .
RUN poetry install --no-root
COPY src/ src/
# 'poetry install' will link to /usr/src/awattprice/src instead of copying it.
RUN poetry install

# Install cron.
RUN apt update
RUN apt -y install cron

RUN crontab -l | { cat; echo "2,*/23 * * * * python /usr/src/awattprice/src/awattprice_notifications/price_below/service.py"; } | crontab -

CMD gunicorn --workers 1 --access-logfile - --bind unix:/etc/awattprice/socket/awattprice.sock -k uvicorn.workers.UvicornWorker awattprice.api:app