#!/usr/bin/env bash
set -euo pipefail

LEFT_VIDEO="/boot/firmware/splash/left.mp4"
RIGHT_VIDEO="/boot/firmware/splash/right.mp4"

/usr/bin/mpv --fs --no-osd-bar --loop=inf --screen=0 "$LEFT_VIDEO" &
LEFT_PID=$!

/usr/bin/mpv --fs --no-osd-bar --loop=inf --screen=1 "$RIGHT_VIDEO" &
RIGHT_PID=$!

wait "$LEFT_PID" "$RIGHT_PID"