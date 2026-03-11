#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/DCM-animath/raspi-dual-mpv.git"
APP_DIR="/opt/raspi-dual-mpv"

if [[ $EUID -ne 0 ]]; then
  echo "Jalankan script ini dengan sudo."
  exit 1
fi

apt-get update
apt-get install -y git mpv ffmpeg python3-gpiozero python3-libgpiod rsync

rm -rf "$APP_DIR"
git clone "$REPO_URL" "$APP_DIR"

rsync -a "$APP_DIR/root/" /

chmod +x /boot/firmware/splash/start_dual.sh || true
chmod +x /boot/firmware/splash/live_monitor.sh || true
chmod +x /boot/firmware/splash/convert_all.sh || true
chmod +x /boot/firmware/splash/mpv_sync_watchdog.py || true
chmod +x /boot/firmware/splash/gpio_switch.py || true

systemctl daemon-reload
systemctl enable dualmp4.service
systemctl enable mpvsync.service
systemctl enable dualgpio.service

echo "Instalasi selesai. Reboot untuk mulai."