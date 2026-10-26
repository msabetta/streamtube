FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg bash \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY backend/requirements.txt ./backend/requirements.txt
RUN pip install --no-cache-dir -r backend/requirements.txt

COPY backend/ ./backend/
COPY transcode/transcode.sh ./transcode/transcode.sh
# Se il file è stato salvato con fine riga Windows (CRLF), bash non lo esegue: li normalizziamo
RUN sed -i 's/\r$//' transcode/transcode.sh && chmod +x transcode/transcode.sh

WORKDIR /app/backend
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]