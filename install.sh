#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/DCM-animath/raspi-dual-mpv.git"
APP_DIR="/opt/raspi-dual-mpv"
SERVICE_DIR="/etc/systemd/system"

if [[ $EUID -ne 0 ]]; then
  echo "Jalankan script ini dengan sudo."
  exit 1
fi

apt-get update
apt-get install -y git mpv python3 python3-gpiozero rsync

rm -rf "$APP_DIR"
git clone "$REPO_URL" "$APP_DIR"

rsync -a "$APP_DIR/root/" /

chmod +x /boot/firmware/splash/start_dual.sh || true
chmod +x /usr/local/bin/live_monitor.sh || true
chmod +x /usr/local/bin/convert_all.sh || true
chmod +x /usr/local/bin/mpv_sync_watchdog.py || true
chmod +x /usr/local/bin/gpio_switch.py || true

systemctl daemon-reload
systemctl enable dualmp4.service
systemctl enable mpvsync.service
systemctl enable dualgpio.service

echo "Instalasi selesai. Reboot untuk mulai."