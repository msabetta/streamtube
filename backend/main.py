import json
import os
import re
import subprocess
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import BackgroundTasks, FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

import shutil

ROOT = Path(__file__).resolve().parent.parent
STORAGE = ROOT / "storage"
UPLOAD_DIR = STORAGE / "uploads"
ALLOWED_EXT = {".mp4", ".mov", ".mkv", ".webm", ".avi"}
CHUNK_SIZE = 1024 * 1024  # 1 MB
ID_RE = re.compile(r"[A-Za-z0-9_-]+")

UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

app = FastAPI(title="StreamTube")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Transcodifiche in corso in questo processo.
# Lo stato persistente sta in storage/<id>/meta.json.
running: set[str] = set()


def meta_path(video_id: str) -> Path:
    return STORAGE / video_id / "meta.json"


def read_meta(video_id: str) -> dict | None:
    p = meta_path(video_id)
    if not p.is_file():
        return None
    return json.loads(p.read_text(encoding="utf-8"))


def write_meta(video_id: str, **fields) -> None:
    p = meta_path(video_id)
    p.parent.mkdir(parents=True, exist_ok=True)
    data = read_meta(video_id) or {"id": video_id}
    data.update(fields)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def load_video(video_id: str) -> dict | None:
    if not ID_RE.fullmatch(video_id):
        return None

    meta = read_meta(video_id)
    if meta is None:
        # Video creati fuori dal backend (es. video1 di test)
        if (STORAGE / video_id / "master.m3u8").is_file():
            return {
                "id": video_id,
                "title": video_id,
                "status": "ready",
                "playlist": f"/media/{video_id}/master.m3u8",
                "created_at": None,
            }
        return None

    # Se il backend è stato riavviato durante una transcodifica, il job è perso
    if meta["status"] == "processing" and video_id not in running:
        meta["status"] = "interrupted"
    return meta


def run_transcode(video_id: str, input_path: Path) -> None:
    out_dir = STORAGE / video_id

    if os.name == "nt":
        cmd = [
            "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
            "-File", str(ROOT / "transcode" / "transcode.ps1"),
            "-InputFile", str(input_path),
            "-OutputDir", str(out_dir),
        ]
    else:
        cmd = ["bash", str(ROOT / "transcode" / "transcode.sh"),
               str(input_path), str(out_dir)]

    try:
        subprocess.run(cmd, check=True)
        write_meta(video_id, status="ready")
    except subprocess.CalledProcessError:
        write_meta(video_id, status="failed")
    finally:
        running.discard(video_id)


@app.post("/api/upload")
async def upload(background: BackgroundTasks, video: UploadFile = File(...)):
    ext = Path(video.filename or "").suffix.lower()
    if ext not in ALLOWED_EXT:
        raise HTTPException(status_code=400, detail=f"Formato non supportato: {ext}")

    video_id = uuid.uuid4().hex
    input_path = UPLOAD_DIR / f"{video_id}{ext}"

    with input_path.open("wb") as f:
        while chunk := await video.read(CHUNK_SIZE):
            f.write(chunk)

    playlist = f"/media/{video_id}/master.m3u8"
    write_meta(
        video_id,
        title=Path(video.filename or video_id).stem,
        original_name=video.filename,
        status="processing",
        created_at=datetime.now(timezone.utc).isoformat(),
        playlist=playlist,
    )

    running.add(video_id)
    background.add_task(run_transcode, video_id, input_path)

    return {"id": video_id, "status": "processing", "playlist": playlist}


@app.get("/api/videos")
def list_videos():
    items = []
    for d in STORAGE.iterdir():
        if d.is_dir() and d.name != "uploads":
            video = load_video(d.name)
            if video:
                items.append(video)
    # Più recenti prima; i video senza data (es. di test) in fondo
    items.sort(key=lambda v: v.get("created_at") or "", reverse=True)
    return items


@app.get("/api/videos/{video_id}")
def video_status(video_id: str):
    video = load_video(video_id)
    if video is None:
        raise HTTPException(status_code=404, detail="Video non trovato")
    return video


@app.delete("/api/videos/{video_id}", status_code=204)
def delete_video(video_id: str):
    if not ID_RE.fullmatch(video_id):
        raise HTTPException(status_code=404, detail="Video non trovato")
    if video_id in running:
        raise HTTPException(status_code=409, detail="Transcodifica in corso, riprova più tardi")

    folder = STORAGE / video_id
    if not folder.is_dir():
        raise HTTPException(status_code=404, detail="Video non trovato")

    # Rimuove la cartella HLS con i metadati e il file originale caricato
    shutil.rmtree(folder)
    for original in UPLOAD_DIR.glob(f"{video_id}.*"):
        original.unlink()