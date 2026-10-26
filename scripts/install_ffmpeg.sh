#!/usr/bin/env bash
set -euo pipefail

if command -v ffmpeg >/dev/null 2>&1; then
  echo "FFmpeg è già installato: $(ffmpeg -version | head -n1)"
  exit 0
fi

echo "FFmpeg non trovato, avvio installazione..."

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "Errore: esegui come root o installa sudo." >&2
    exit 1
  fi
fi

if [ "$(uname -s)" = "Darwin" ]; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Errore: Homebrew non trovato. Installalo da https://brew.sh" >&2
    exit 1
  fi
  brew install ffmpeg

elif [ -f /etc/os-release ]; then
  . /etc/os-release
  case "$ID" in
    ubuntu|debian)
      $SUDO apt-get update -y
      $SUDO apt-get install -y ffmpeg
      ;;
    rhel|rocky|almalinux|centos|fedora)
      # ffmpeg su RHEL/Rocky richiede EPEL + RPM Fusion (o il repo ffmpeg-free)
      if ! rpm -q epel-release >/dev/null 2>&1; then
        $SUDO dnf install -y epel-release || true
      fi
      $SUDO dnf install -y ffmpeg || {
        echo "Installazione da repo di sistema fallita." >&2
        echo "Su RHEL/Rocky valuta RPM Fusion: https://rpmfusion.org" >&2
        exit 1
      }
      ;;
    *)
      echo "Distribuzione non supportata automaticamente: $ID" >&2
      echo "Installa FFmpeg manualmente: https://ffmpeg.org/download.html" >&2
      exit 1
      ;;
  esac
else
  echo "Sistema operativo non riconosciuto." >&2
  exit 1
fi

if command -v ffmpeg >/dev/null 2>&1; then
  echo "FFmpeg installato con successo: $(ffmpeg -version | head -n1)"
else
  echo "Installazione completata ma ffmpeg non risulta nel PATH." >&2
  exit 1
fi