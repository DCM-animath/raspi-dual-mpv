#!/bin/bash
# start_dual.sh - Jalankan dua instance MPV di dua monitor
# gpio_switch.py akan handle load video pertama (idle set)

export XDG_RUNTIME_DIR=/run/user/1000
export WAYLAND_DISPLAY=wayland-0

# Bersihkan proses dan socket lama
pkill -f "mpv.*boot/firmware/splash" 2>/dev/null
sleep 0.5
rm -f /tmp/mpv-left.sock /tmp/mpv-right.sock

echo "[INFO] Menunggu runtime dir..."
while [ ! -d /run/user/1000 ]; do
  sleep 1
done

echo "[INFO] Menunggu Wayland socket..."
while [ ! -S /run/user/1000/wayland-0 ]; do
  sleep 1
done

echo "[INFO] Wayland siap, start MPV..."

# Argumen MPV yang dipakai bersama kedua instance
MPV_COMMON=(
  --no-config
  --no-terminal
  --no-osc
  --no-audio
  --fullscreen
  --loop-file=inf
  --force-window=immediate
  --idle=yes

  # Hardware decode H.265 via v4l2m2m (RPi5)
  # Jika ada masalah, ganti dengan: --hwdec=auto-safe
  --hwdec=v4l2m2m-copy
  --vo=gpu
  --gpu-context=wayland

  # Tuning sinkronisasi & memori
  --video-sync=display-resample
  --interpolation=no
  --cache=no
  --demuxer-readahead-secs=0
  --vd-lavc-threads=2
)

# Monitor kiri (HDMI-A-2)
mpv "${MPV_COMMON[@]}" \
  --fs-screen-name=HDMI-A-2 \
  --input-ipc-server=/tmp/mpv-left.sock \
  &

# Monitor kanan (HDMI-A-1)
mpv "${MPV_COMMON[@]}" \
  --fs-screen-name=HDMI-A-1 \
  --input-ipc-server=/tmp/mpv-right.sock \
  &

echo "[INFO] MPV kiri & kanan berjalan, menunggu..."
wait
