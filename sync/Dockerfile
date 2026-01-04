FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash git openssh-client ca-certificates tzdata git-crypt \
  && rm -rf /var/lib/apt/lists/*

# Install beancount v3 for parse checks
RUN pip install --no-cache-dir "beancount>=3,<4"

# supercronic for reliable cron in containers
ADD https://github.com/aptible/supercronic/releases/download/v0.2.29/supercronic-linux-arm64 /usr/local/bin/supercronic
RUN chmod +x /usr/local/bin/supercronic

WORKDIR /app
COPY entrypoint.sh sync_once.sh notify_email.py crontab /app/
RUN chmod +x /app/entrypoint.sh /app/sync_once.sh

ENV PYTHONUNBUFFERED=1
ENTRYPOINT ["/app/entrypoint.sh"]
