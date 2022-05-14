# syntax:docker/dockerfile:1

# Build command (assuming you're in the `backend` directory).
# docker build -f docker/Dockerfile -t leonbecker1/awattprice-backend ..

# The docker image created from this Dockerfile includes the v2 backend as well as the modified v1 backend to support backwards compatibility. Both get installed inside this image.

FROM python:3.10
SHELL ["/bin/bash", "-c"]

RUN mkdir /usr/src/awattprice/ && mkdir /usr/src/v1_awattprice/

# Install tools.
RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="/root/.local/bin:$PATH"
RUN pip install virtualenv==20.14.1
RUN apt-get update && apt-get install -y cron

# Setup virtual environments (see https://pythonspeed.com/articles/activate-virtualenv-dockerfile/).
ENV VIRTUAL_ENV_AWATTPRICE=/opt/venvs/awattprice
ENV VIRTUAL_ENV_V1_AWATTPRICE=/opt/venvs/v1_awattprice
RUN python3 -m venv $VIRTUAL_ENV_AWATTPRICE && python3 -m venv $VIRTUAL_ENV_V1_AWATTPRICE

ENV ORIGINAL_PATH="$PATH"

# Install v2 backend dependencies.
WORKDIR /usr/src/awattprice/
ENV VIRTUAL_ENV="$VIRTUAL_ENV_AWATTPRICE"
ENV PATH="$VIRTUAL_ENV/bin:$ORIGINAL_PATH"
COPY backend/pyproject.toml .
COPY backend/poetry.lock .
RUN poetry install --no-root
COPY backend/src/ src/
RUN ls -a
# 'poetry install' will link to /usr/src/awattprice/src instead of copying it.
RUN poetry install

# Install v1 backend dependencies.
WORKDIR /usr/src/v1_awattprice/
ENV VIRTUAL_ENV="$VIRTUAL_ENV_V1_AWATTPRICE"
ENV PATH="$VIRTUAL_ENV/bin:$ORIGINAL_PATH"
COPY v1_backend/requirements.txt .
RUN pip install -r requirements.txt
COPY v1_backend/ .
RUN git init && pip install .

ENV VIRTUAL_ENV="$VIRTUAL_ENV_AWATTPRICE"
ENV PATH="$VIRTUAL_ENV_AWATTPRICE/bin:$ORIGINAL_PATH"

# Setup cron (see https://blog.thesparktree.com/cron-in-docker).
RUN rm -rf /etc/cron.*/* && env >> /etc/environment
RUN echo -e "SHELL=/bin/sh \nPATH=$PATH \n2,*/23 * * * * root python /usr/src/awattprice/src/awattprice_notifications/price_below/service.py" > /etc/crontab
RUN echo "* * * * * root env > /root/test.txt" >> /etc/crontab

CMD cron -f & \
	
	gunicorn --workers 1 --access-logfile - --bind unix:/etc/awattprice/socket/awattprice.sock -k uvicorn.workers.UvicornWorker awattprice.api:app & \
	
	PYTHONPATH="/opt/venvs/v1_awattprice/lib/python3.10/site-packages:$PYTHONPATH" gunicorn --workers 1 --access-logfile - --bind unix:/etc/v1_awattprice/socket/awattprice.sock -k uvicorn.workers.UvicornWorker v1_awattprice.fastapi_conf.api:api