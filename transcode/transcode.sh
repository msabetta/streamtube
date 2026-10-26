#!/usr/bin/env bash
set -euo pipefail

INPUT="$1"
OUT_DIR="$2"
mkdir -p "$OUT_DIR"

ffmpeg -y -i "$INPUT" \
  -filter_complex "[0:v]split=3[v1][v2][v3]; \
    [v1]scale=-2:360[v360]; \
    [v2]scale=-2:720[v720]; \
    [v3]scale=-2:1080[v1080]" \
  -map "[v360]" -map 0:a -c:v:0 libx264 -b:v:0 800k -c:a aac -b:a 96k \
  -map "[v720]" -map 0:a -c:v:1 libx264 -b:v:1 2800k -c:a aac -b:a 128k \
  -map "[v1080]" -map 0:a -c:v:2 libx264 -b:v:2 5000k -c:a aac -b:a 192k \
  -f hls -hls_time 6 -hls_playlist_type vod \
  -hls_segment_filename "$OUT_DIR/v%v/seg_%03d.ts" \
  -master_pl_name master.m3u8 \
  -var_stream_map "v:0,a:0 v:1,a:1 v:2,a:2" \
  "$OUT_DIR/v%v/index.m3u8"