$ErrorActionPreference = "Stop"

if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
    $version = (ffmpeg -version | Select-Object -First 1)
    Write-Host "FFmpeg è già installato: $version"
    exit 0
}

Write-Host "FFmpeg non trovato, avvio installazione..."

if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements
}
elseif (Get-Command choco -ErrorAction SilentlyContinue) {
    choco install ffmpeg -y
}
else {
    Write-Error "Né winget né Chocolatey sono disponibili. Installa FFmpeg da https://ffmpeg.org/download.html"
    exit 1
}

# Aggiorna il PATH della sessione corrente
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")

if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
    Write-Host "FFmpeg installato con successo: $(ffmpeg -version | Select-Object -First 1)"
} else {
    Write-Warning "Installazione completata, ma ffmpeg non è ancora nel PATH. Riapri PowerShell e riprova."
    exit 1
}