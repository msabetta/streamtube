# StreamTube

Piattaforma di video streaming in stile YouTube, sviluppata per imparare l'architettura di un servizio di streaming adattivo (HLS): upload, transcodifica multi-qualità, distribuzione dei segmenti e riproduzione nel browser.

## Funzionalità

- Upload di video con barra di progresso e drag & drop
- Transcodifica automatica in HLS a tre qualità (360p, 720p, 1080p) con FFmpeg
- Riproduzione adattiva nel browser tramite hls.js (Safari usa HLS nativo)
- Elenco dei video con stato di elaborazione (in elaborazione, pronto, fallito, interrotto)
- Eliminazione dei video
- Link condivisibili per la riproduzione (`/?v=<id>`)
- Documentazione interattiva delle API (Swagger UI)

## Architettura

```
Browser ──► nginx (porta 8080) ──┬──► /media/*   file HLS statici (storage/)
                                 ├──► /api/*     backend FastAPI
                                 └──► /web/*     pagine statiche (web/)

Backend FastAPI ──► FFmpeg (transcode.sh) ──► storage/<id>/
```

Il backend e nginx girano in container Docker separati, collegati tramite la rete interna di Compose. Il backend non espone porte sull'host: è raggiungibile solo attraverso nginx.

## Struttura del progetto

```
streamtube/
├── backend/
│   ├── Dockerfile
│   ├── main.py            # API FastAPI
│   └── requirements.txt
├── transcode/
│   ├── transcode.sh       # transcodifica HLS (Linux, usato nel container)
│   └── transcode.ps1      # stessa logica per Windows PowerShell
├── scripts/
│   ├── install_ffmpeg.sh  # installazione FFmpeg su Linux/macOS
│   └── install_ffmpeg.ps1 # installazione FFmpeg su Windows
├── storage/               # video caricati e output HLS (non versionato)
├── web/
│   ├── assets/
│   │   ├── app.css        # stili condivisi
│   │   └── nav.js         # barra di navigazione e notifiche
│   ├── index.html         # pagina di riproduzione
│   ├── upload.html        # pagina di gestione
│   └── 404.html
├── nginx.conf
├── docker-compose.yml
└── .dockerignore
```

## Requisiti

- Docker Desktop (Windows) o Docker Engine con Compose v2
- Per gli script di supporto su Windows: PowerShell 5.1 o superiore
- FFmpeg sull'host solo se vuoi eseguire la transcodifica fuori da Docker (lo script `scripts/install_ffmpeg.ps1` lo installa tramite winget o Chocolatey)

## Avvio rapido

Dalla radice del progetto:

```powershell
docker compose up -d --build
```

Poi apri:

- Riproduzione: http://localhost:8080
- Gestione video: http://localhost:8080/upload.html
- Documentazione API: http://localhost:8080/docs

Per fermare i servizi:

```powershell
docker compose down
```

## Utilizzo

1. Apri la pagina **Gestione**, trascina un video nell'area di upload e clicca **Carica e transcodifica**.
2. Attendi che lo stato passi da "in elaborazione" a "pronto". Può richiedere alcuni minuti in base alla durata del file.
3. Dalla pagina **Guarda** seleziona il video dall'elenco, oppure usa il pulsante **Guarda** nella tabella di gestione.

Formati accettati: MP4, MOV, MKV, WEBM, AVI.

### Video di test

Per creare un video di prova, copia un file `sample.mp4` in `storage/` e lancia la transcodifica dal container:

```powershell
docker compose exec backend bash /app/transcode/transcode.sh /app/storage/sample.mp4 /app/storage/video1
```

Il video comparirà come `video1` in riproduzione diretta su `http://localhost:8080/?v=video1` solo se contiene `master.m3u8`.

## API

| Metodo | Endpoint | Descrizione |
|--------|----------|-------------|
| `POST` | `/api/upload` | Riceve il file (campo `video`) e avvia la transcodifica. Restituisce `id`, `status`, `playlist`. |
| `GET` | `/api/videos` | Elenco dei video, dal più recente. |
| `GET` | `/api/videos/{id}` | Stato e metadati di un video. |
| `DELETE` | `/api/videos/{id}` | Elimina il video e i suoi file. Restituisce 409 se è in elaborazione. |

Lo schema completo è disponibile su `/docs` e `/openapi.json`.

## Persistenza

- I file caricati e la transcodifica sono in `storage/`, condiviso tra backend e nginx tramite un bind mount.
- I metadati di ogni video sono in `storage/<id>/meta.json`, quindi l'elenco sopravvive ai riavvii.
- Lo stato delle transcodifiche in corso è in memoria: se il backend si riavvia durante un'elaborazione, il video risulta "interrotto" e va ricaricato.

## Limiti noti

- La transcodifica gira nello stesso processo del backend, senza coda: più upload contemporanei competono per la CPU.
- Lo script assume che ogni video abbia una traccia audio (`-map 0:a`). Un file muto fa fallire la transcodifica.
- Nessuna autenticazione: chiunque raggiunga la porta 8080 può caricare ed eliminare video.
- CORS è aperto a tutte le origini (`*`).
- Non c'è un database: i metadati sono file JSON.

## Roadmap

- [ ] Pagina di dettaglio per video, con rinomina del titolo e informazioni tecniche (durata, risoluzioni, dimensione)
- [ ] Database PostgreSQL per i metadati
- [ ] Coda di transcodifica (Redis o RabbitMQ) con worker separati
- [ ] Storage S3-compatibile (MinIO) al posto della cartella locale
- [ ] Miniature generate con FFmpeg
- [ ] Autenticazione e gestione utenti
- [ ] URL firmati per proteggere i contenuti
- [ ] Live streaming (ingest RTMP/SRT)

## Licenza

TBD