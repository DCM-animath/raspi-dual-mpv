#!/bin/bash
# live_monitor.sh - Monitor status MPV dan GPIO secara live

LEFT_SOCK="/tmp/mpv-left.sock"
RIGHT_SOCK="/tmp/mpv-right.sock"
MODE_FILE="/tmp/mpv-mode"

get_prop() {
  local sock="$1"
  local prop="$2"
  echo "{\"command\": [\"get_property\", \"$prop\"]}" \
    | socat - "$sock" 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data','N/A'))" 2>/dev/null \
    || echo "N/A"
}

format_time() {
  local t="$1"
  if [[ "$t" == "N/A" ]] || [[ -z "$t" ]]; then
    echo "N/A"
    return
  fi
  printf "%.2fs" "$t"
}

while true; do
  clear
  echo "╔══════════════════════════════════════╗"
  echo "║        LIVE MONITOR - DUAL MPV       ║"
  echo "╚══════════════════════════════════════╝"
  date "+  %Y-%m-%d %H:%M:%S"
  echo

  MODE=$(cat "$MODE_FILE" 2>/dev/null || echo "unknown")
  echo "  Mode saat ini : $MODE"
  echo

  echo "  ┌─ LEFT (HDMI-A-2) ──────────────────"
  L_FILE=$(get_prop "$LEFT_SOCK" "filename")
  L_TIME=$(get_prop "$LEFT_SOCK" "playback-time")
  L_DUR=$(get_prop  "$LEFT_SOCK" "duration")
  L_PAUSE=$(get_prop "$LEFT_SOCK" "pause")
  echo "  │  File   : $L_FILE"
  echo "  │  Time   : $(format_time "$L_TIME") / $(format_time "$L_DUR")"
  echo "  │  Paused : $L_PAUSE"
  echo "  └────────────────────────────────────"
  echo

  echo "  ┌─ RIGHT (HDMI-A-1) ─────────────────"
  R_FILE=$(get_prop "$RIGHT_SOCK" "filename")
  R_TIME=$(get_prop "$RIGHT_SOCK" "playback-time")
  R_DUR=$(get_prop  "$RIGHT_SOCK" "duration")
  R_PAUSE=$(get_prop "$RIGHT_SOCK" "pause")
  echo "  │  File   : $R_FILE"
  echo "  │  Time   : $(format_time "$R_TIME") / $(format_time "$R_DUR")"
  echo "  │  Paused : $R_PAUSE"
  echo "  └────────────────────────────────────"
  echo

  # Hitung drift
  if [[ "$L_TIME" != "N/A" && "$R_TIME" != "N/A" ]]; then
    DRIFT=$(python3 -c "print(f'{abs(${L_TIME} - ${R_TIME}):.3f}s')" 2>/dev/null || echo "N/A")
    echo "  Drift L↔R  : $DRIFT"
  fi

  echo
  echo "  [GPIO Log Terakhir]"
  journalctl -u dualgpio.service -n 5 --no-pager 2>/dev/null \
    | grep -E "GPIO|set [0-9]|IDLE|ONESHOT" | tail -n 5 | sed 's/^/  /'
  echo
  echo "  (Ctrl+C untuk keluar)"

  sleep 0.5
done
