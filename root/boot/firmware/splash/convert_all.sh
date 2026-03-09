#!/bin/bash
# convert_all.sh - Batch convert video ke H.264 720p untuk MPV di RPi5
# H.264 dipakai karena hardware decode (v4l2m2m) lebih stabil di RPi5 vs H.265
set -euo pipefail

DIR="/boot/firmware/splash"
SET_COUNT=6

# ── Parameter encode ──────────────────────────────────────────────────────────
WIDTH=1280
HEIGHT=720
FPS=30
CRF=23        # H.264: 23 = quality bagus. Naikkan ke 26-28 untuk file lebih kecil
PRESET="fast" # fast = keseimbangan kecepatan/size di RPi5

SERVICES=(
  "dualgpio.service"
  "mpvsync.service"
  "dualmp4.service"
)

# ── Stop services ──────────────────────────────────────────────────────────────
echo "=== Stop services ==="
for svc in "${SERVICES[@]}"; do
  sudo systemctl stop "$svc" 2>/dev/null && echo "[OK] $svc stopped" || true
done
echo

# ── Hitung total file untuk progress ─────────────────────────────────────────
TOTAL=$(( SET_COUNT * 2 ))
COUNT=0

convert_file() {
  local input="$1"
  local temp="${input%.mp4}.converted.mp4"
  COUNT=$(( COUNT + 1 ))

  if [ ! -f "$input" ]; then
    echo "[$COUNT/$TOTAL] [SKIP] Tidak ada: $input"
    return
  fi

  echo "[$COUNT/$TOTAL] [CONVERT] $input"

  ffmpeg -y \
    -i "$input" \
    -vf "fps=${FPS},scale=${WIDTH}:${HEIGHT}:flags=lanczos,format=yuv420p" \
    -r "$FPS" \
    -an \
    -c:v libx264 \
    -preset "$PRESET" \
    -crf "$CRF" \
    -movflags +faststart \
    "$temp" 2>&1 | grep -E "frame=|fps=|time=|error" || true

  if [ -f "$temp" ]; then
    rm -f "$input"
    mv "$temp" "$input"
    echo "[$COUNT/$TOTAL] [DONE] $input"
  else
    echo "[$COUNT/$TOTAL] [ERROR] Gagal convert: $input"
  fi
}

# ── Proses semua set ──────────────────────────────────────────────────────────
echo "=== Mulai convert ($TOTAL file) ==="
for i in $(seq 1 "$SET_COUNT"); do
  convert_file "$DIR/${i}-left.mp4"
  convert_file "$DIR/${i}-right.mp4"
done

echo
echo "=== Semua convert selesai ==="

# ── Restart services ──────────────────────────────────────────────────────────
echo "=== Restart services ==="
sudo systemctl start dualmp4.service && echo "[OK] dualmp4.service started" || echo "[ERROR] dualmp4 gagal start"
sleep 3
sudo systemctl start mpvsync.service  && echo "[OK] mpvsync.service started"  || echo "[ERROR] mpvsync gagal start"
sudo systemctl start dualgpio.service && echo "[OK] dualgpio.service started" || echo "[ERROR] dualgpio gagal start"

echo
echo "=== Selesai ==="
