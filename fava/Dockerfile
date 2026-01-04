FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates tzdata \
  && rm -rf /var/lib/apt/lists/*

# Beancount v3 + Fava
RUN pip install --no-cache-dir "beancount>=3,<4" "fava>=1.30"

ENV PYTHONUNBUFFERED=1


EXPOSE 5000
CMD ["sh", "-lc", "fava --host 0.0.0.0 --port 5000 \"$BEAN_FILE\""]
CMD ["sh", "-lc", "export BEAN_FILE_PATH=\"/data/repo/${BEAN_FILE}\" && fava --host 0.0.0.0 --port 5000 \"$BEAN_FILE_PATH\""]
