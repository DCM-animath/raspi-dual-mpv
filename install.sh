#!/bin/bash
# ============================================================
#  install.sh — Install Dual MPV Player dari GitHub ke RPi5
#
#  Cara pakai (jalankan di RPi):
#  curl -fsSL https://raw.githubusercontent.com/GITHUB_USER/REPO_NAME/main/install.sh | bash
# ============================================================
set -euo pipefail

# ── KONFIGURASI — sesuaikan setelah upload ke GitHub ────────
GITHUB_USER="isi_username_github_kamu"
REPO_NAME="raspi-dual-mpv"
BRANCH="main"
# ────────────────────────────────────────────────────────────

REPO_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"
RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}"
SPLASH_DIR="/boot/firmware/splash"
SERVICE_DIR="/etc/systemd/system"
INSTALL_DIR="/tmp/raspi-dual-mpv-install"

# ── Warna ────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "  ${CYAN}[INFO]${NC}  $*"; }
ok()      { echo -e "  ${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "  ${YELLOW}[WARN]${NC}  $*"; }
err()     { echo -e "  ${RED}[ERROR]${NC} $*"; exit 1; }
section() { echo -e "\n${BOLD}${CYAN}── $* ──${NC}"; }

# ── Banner ────────────────────────────────────────────────────
clear
echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════╗"
echo "║     INSTALL — Dual MPV Player — RPi5            ║"
echo "║     Sumber: github.com/${GITHUB_USER}/${REPO_NAME}"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Cek root ─────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  # Re-run sebagai sudo otomatis
  info "Re-run sebagai root..."
  exec sudo bash "$0" "$@"
fi

# ── Cek internet ─────────────────────────────────────────────
section "1. Cek Koneksi Internet"
if curl -fsSL --max-time 10 https://github.com > /dev/null 2>&1; then
  ok "Koneksi ke GitHub OK"
else
  err "Tidak bisa akses GitHub. Cek koneksi internet RPi."
fi

# ── Install git & dependencies ────────────────────────────────
section "2. Install Packages"
info "Update apt & install packages..."
apt-get update -qq
apt-get install -y git mpv ffmpeg socat python3-pip
ok "Packages terinstall: git mpv ffmpeg socat"

# python3-gpiod - coba apt dulu, fallback ke pip
info "Install python3-gpiod..."
if apt-get install -y python3-gpiod 2>/dev/null; then
  ok "python3-gpiod terinstall via apt"
elif apt-get install -y python3-libgpiod 2>/dev/null; then
  ok "python3-libgpiod terinstall via apt"
else
  info "Fallback: install gpiod via pip..."
  pip3 install gpiod --break-system-packages
  ok "gpiod terinstall via pip"
fi

# ── Clone / update repo ───────────────────────────────────────
section "3. Download dari GitHub"
if [ -d "$INSTALL_DIR/.git" ]; then
  info "Repo sudah ada, pull update..."
  git -C "$INSTALL_DIR" pull --rebase origin "$BRANCH"
  ok "Repo diupdate"
else
  info "Clone repo: $REPO_URL"
  rm -rf "$INSTALL_DIR"
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
  ok "Repo di-clone"
fi

# ── Validasi file ada ─────────────────────────────────────────
section "4. Validasi File"
REQUIRED=(
  "root/boot/firmware/splash/start_dual.sh"
  "root/boot/firmware/splash/gpio_switch.py"
  "root/boot/firmware/splash/mpv_sync_watchdog.py"
  "root/boot/firmware/splash/convert_all.sh"
  "root/boot/firmware/splash/live_monitor.sh"
  "root/etc/systemd/system/dualmp4.service"
  "root/etc/systemd/system/mpvsync.service"
  "root/etc/systemd/system/dualgpio.service"
)

for f in "${REQUIRED[@]}"; do
  if [ -f "$INSTALL_DIR/$f" ]; then
    ok "$f"
  else
    err "File tidak ditemukan di repo: $f"
  fi
done

# ── Stop service lama ─────────────────────────────────────────
section "5. Stop Service Lama"
systemctl stop dualmp4.service mpvsync.service dualgpio.service 2>/dev/null || true
ok "Service lama dihentikan (jika ada)"

# ── Deploy script ke splash dir ───────────────────────────────
section "6. Deploy Script"
mkdir -p "$SPLASH_DIR"
chown pi:pi "$SPLASH_DIR"

SPLASH_FILES=(
  start_dual.sh
  gpio_switch.py
  mpv_sync_watchdog.py
  convert_all.sh
  live_monitor.sh
)

for f in "${SPLASH_FILES[@]}"; do
  cp "$INSTALL_DIR/root/boot/firmware/splash/$f" "$SPLASH_DIR/$f"
  ok "Copy: $f → $SPLASH_DIR/"
done

# Set permission executable
chmod +x "$SPLASH_DIR/start_dual.sh" \
         "$SPLASH_DIR/convert_all.sh" \
         "$SPLASH_DIR/live_monitor.sh"
ok "Permission +x diset"

# ── Deploy service files ──────────────────────────────────────
section "7. Deploy Systemd Services"
for f in dualmp4.service mpvsync.service dualgpio.service; do
  cp "$INSTALL_DIR/root/etc/systemd/system/$f" "$SERVICE_DIR/$f"
  chmod 644 "$SERVICE_DIR/$f"
  ok "Deploy: $f"
done

systemctl daemon-reload
systemctl enable dualmp4.service mpvsync.service dualgpio.service
ok "Services di-enable (autostart aktif)"

# ── Cek file video ────────────────────────────────────────────
section "8. Cek File Video"
MISSING=0
for i in $(seq 1 6); do
  for side in left right; do
    VFILE="$SPLASH_DIR/${i}-${side}.mp4"
    if [ -f "$VFILE" ]; then
      ok "${i}-${side}.mp4"
    else
      warn "TIDAK ADA: ${i}-${side}.mp4"
      MISSING=$(( MISSING + 1 ))
    fi
  done
done

# ── Bersihkan temp ────────────────────────────────────────────
rm -rf "$INSTALL_DIR"

# ── Ringkasan ─────────────────────────────────────────────────
echo
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  Install selesai!${NC}"
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════${NC}"
echo

if [ "$MISSING" -gt 0 ]; then
  echo -e "  ${YELLOW}⚠  $MISSING file video belum ada di $SPLASH_DIR${NC}"
  echo -e "  Letakkan file: 1-left.mp4, 1-right.mp4, ..., 6-right.mp4"
  echo -e "  Lalu jalankan convert jika perlu: sudo bash $SPLASH_DIR/convert_all.sh"
  echo
fi

echo -e "  Untuk mulai, reboot RPi:"
echo -e "  ${BOLD}sudo reboot${NC}"
echo