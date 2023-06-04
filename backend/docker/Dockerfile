# syntax:docker/dockerfile:1

# Build command (assuming you're in the `backend` directory).
# docker build -f docker/Dockerfile -t leonbecker1/awattprice-backend ..
# Note that the docker image is created for the architecture of the machine this command is executed on. If you'd like create the image for a different architecture it's easiest to create the image on the machine with the different architecture.

# The docker image created from this Dockerfile includes the v2 backend. Since 4th of June 2023 the v1 backend isn't included anymore and support for this version is terminated. It was supported almost one year after releasing the v2 backend to ensure backwards compatibility.

FROM python:3.10
SHELL ["/bin/bash", "-c"]

RUN mkdir /usr/src/awattprice/

# Install tools.
RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="/root/.local/bin:$PATH"
RUN pip install virtualenv==20.14.1
RUN apt-get update && apt-get install -y cron

# Setup virtual environments (see https://pythonspeed.com/articles/activate-virtualenv-dockerfile/).
ENV VIRTUAL_ENV_AWATTPRICE=/opt/venvs/awattprice
RUN python3 -m venv $VIRTUAL_ENV_AWATTPRICE

ENV ORIGINAL_PATH="$PATH"

# Install v2 backend dependencies.
WORKDIR /usr/src/awattprice/
ENV VIRTUAL_ENV="$VIRTUAL_ENV_AWATTPRICE"
ENV PATH="$VIRTUAL_ENV/bin:$ORIGINAL_PATH"
COPY backend/pyproject.toml .
COPY backend/poetry.lock .
RUN poetry install --no-root
COPY backend/src/ src/
# 'poetry install' will link to /usr/src/awattprice/src instead of copying it.
RUN poetry install

# Setup cron (see https://blog.thesparktree.com/cron-in-docker).
RUN rm -rf /etc/cron.*/* && env >> /etc/environment
RUN echo -e "SHELL=/bin/sh \nPATH=$PATH \n2,*/23 * * * * root python /usr/src/awattprice/src/awattprice_notifications/price_below/service.py" > /etc/crontab
RUN echo "* * * * * root env > /root/test.txt" >> /etc/crontab

CMD cron -f & \
	gunicorn --workers 1 --access-logfile - --bind unix:/etc/awattprice/socket/awattprice.sock -k uvicorn.workers.UvicornWorker awattprice.api:app