#!/usr/bin/env bash
set -euo pipefail

INPUT_DIR="${1:-.}"
OUTPUT_DIR="${2:-./converted}"
mkdir -p "$OUTPUT_DIR"

find "$INPUT_DIR" -maxdepth 1 -type f \( -iname "*.mov" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mp4" \) | while read -r file; do
  name="$(basename "$file")"
  out="$OUTPUT_DIR/${name%.*}.mp4"
  ffmpeg -y -i "$file" -c:v libx264 -preset medium -crf 23 -c:a aac "$out"
done