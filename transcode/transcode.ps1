param(
    [Parameter(Mandatory = $true)][string]$InputFile,
    [Parameter(Mandatory = $true)][string]$OutputDir
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Error "ffmpeg non trovato nel PATH. Esegui prima scripts\install_ffmpeg.ps1"
    exit 1
}

if (-not (Test-Path -LiteralPath $InputFile)) {
    Write-Error "File di input non trovato: $InputFile"
    exit 1
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
0..2 | ForEach-Object {
    New-Item -ItemType Directory -Force -Path (Join-Path $OutputDir "v$_") | Out-Null
}

$filter = "[0:v]split=3[v1][v2][v3];" +
          "[v1]scale=-2:360[v360];" +
          "[v2]scale=-2:720[v720];" +
          "[v3]scale=-2:1080[v1080]"

$ffmpegArgs = @(
    "-y", "-i", $InputFile,
    "-filter_complex", $filter,
    "-map", "[v360]", "-map", "0:a", "-c:v:0", "libx264", "-b:v:0", "800k",  "-c:a:0", "aac", "-b:a:0", "96k",
    "-map", "[v720]", "-map", "0:a", "-c:v:1", "libx264", "-b:v:1", "2800k", "-c:a:1", "aac", "-b:a:1", "128k",
    "-map", "[v1080]", "-map", "0:a", "-c:v:2", "libx264", "-b:v:2", "5000k", "-c:a:2", "aac", "-b:a:2", "192k",
    "-f", "hls", "-hls_time", "6", "-hls_playlist_type", "vod",
    "-hls_segment_filename", "$OutputDir\v%v\seg_%03d.ts",
    "-master_pl_name", "master.m3u8",
    "-var_stream_map", "v:0,a:0 v:1,a:1 v:2,a:2",
    "$OutputDir\v%v\index.m3u8"
)

& ffmpeg @ffmpegArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "Transcodifica fallita (exit code $LASTEXITCODE)."
    exit $LASTEXITCODE
}

Write-Host "Transcodifica completata: $OutputDir\master.m3u8"