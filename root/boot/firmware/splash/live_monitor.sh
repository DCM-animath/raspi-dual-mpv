#!/usr/bin/env bash
set -euo pipefail

watch -n 1 '
  echo "=== MPV ==="
  pgrep -af mpv || true
  echo
  echo "=== SERVICES ==="
  systemctl --no-pager --full status dualmp4.service mpvsync.service dualgpio.service | sed -n "1,80p"
'