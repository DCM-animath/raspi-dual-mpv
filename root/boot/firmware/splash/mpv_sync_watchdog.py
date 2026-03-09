#!/usr/bin/env python3
"""
mpv_sync_watchdog.py
Memantau sinkronisasi dua instance MPV dan melakukan resync jika drift > MAX_DRIFT.
Membaca /tmp/mpv-mode untuk skip resync agresif saat mode oneshot (video sedang diputar tombol).
"""

import json
import os
import socket
import sys
import time
import signal

LEFT_SOCK  = "/tmp/mpv-left.sock"
RIGHT_SOCK = "/tmp/mpv-right.sock"
MODE_FILE  = "/tmp/mpv-mode"   # ditulis oleh gpio_switch.py

# ── Threshold ────────────────────────────────────────────────────────────────
CHECK_INTERVAL   = 0.020   # 20ms polling
MAX_DRIFT        = 0.030   # 30ms → ~1 frame di 30fps
LOOP_MARGIN      = 0.060   # detik sebelum loop end untuk trigger resync
MIN_RESYNC_GAP   = 0.80    # cooldown antar resync (detik)

# Saat oneshot: izinkan drift lebih longgar agar tidak interrupt video
ONESHOT_MAX_DRIFT = 0.200  # 200ms, hanya resync jika sangat parah

last_resync_time = 0.0


def cleanup(*_):
    sys.exit(0)


signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGINT, cleanup)


def wait_for_socket(path: str, timeout: int = 30):
    start = time.time()
    while time.time() - start < timeout:
        if os.path.exists(path):
            return
        time.sleep(0.1)
    raise TimeoutError(f"Socket tidak muncul: {path}")


def mpv_cmd(sock_path: str, command: list):
    """Kirim perintah IPC ke MPV. Return dict atau None jika gagal."""
    payload = json.dumps({"command": command}) + "\n"
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(1.0)
    try:
        s.connect(sock_path)
        s.sendall(payload.encode("utf-8"))
        data = b""
        try:
            data = s.recv(4096)
        except Exception:
            pass
        s.close()
        if not data:
            return None
        return json.loads(data.decode("utf-8", errors="ignore"))
    except Exception:
        try:
            s.close()
        except Exception:
            pass
        return None


def get_prop(sock_path: str, prop: str):
    resp = mpv_cmd(sock_path, ["get_property", prop])
    if isinstance(resp, dict):
        return resp.get("data")
    return None


def set_pause(sock_path: str, state: bool):
    mpv_cmd(sock_path, ["set_property", "pause", state])


def seek_zero(sock_path: str):
    mpv_cmd(sock_path, ["seek", 0, "absolute", "exact"])


def get_current_mode() -> str:
    """Baca mode dari file. Default 'idle' jika tidak ada."""
    try:
        with open(MODE_FILE, "r") as f:
            return f.read().strip()
    except Exception:
        return "idle"


def resync(reason: str):
    global last_resync_time
    now = time.time()
    if now - last_resync_time < MIN_RESYNC_GAP:
        return

    try:
        # Pause kedua player
        set_pause(LEFT_SOCK,  True)
        set_pause(RIGHT_SOCK, True)

        # Seek ke awal bersamaan
        seek_zero(LEFT_SOCK)
        seek_zero(RIGHT_SOCK)

        # Play bersamaan
        set_pause(LEFT_SOCK,  False)
        set_pause(RIGHT_SOCK, False)

        last_resync_time = now
        print(f"[INFO] Resync: {reason}", flush=True)
    except Exception as e:
        print(f"[WARN] Resync gagal: {e}", flush=True)


def main():
    wait_for_socket(LEFT_SOCK)
    wait_for_socket(RIGHT_SOCK)
    print("[INFO] Sync watchdog aktif", flush=True)

    while True:
        try:
            lt = get_prop(LEFT_SOCK,  "playback-time")
            rt = get_prop(RIGHT_SOCK, "playback-time")
            ld = get_prop(LEFT_SOCK,  "duration")
            rd = get_prop(RIGHT_SOCK, "duration")

            if None in (lt, rt, ld, rd):
                time.sleep(CHECK_INTERVAL)
                continue

            lt = float(lt)
            rt = float(rt)
            ld = float(ld)
            rd = float(rd)

            drift    = abs(lt - rt)
            loop_end = min(ld, rd) - LOOP_MARGIN
            mode     = get_current_mode()

            if mode == "oneshot":
                # Saat oneshot: hanya resync jika drift sangat parah
                if drift > ONESHOT_MAX_DRIFT:
                    resync(f"oneshot drift parah {drift:.3f}s")
            else:
                # Mode idle: resync ketat
                if drift > MAX_DRIFT:
                    resync(f"drift {drift:.3f}s")
                elif lt >= loop_end or rt >= loop_end:
                    resync("loop boundary")

        except Exception as e:
            print(f"[WARN] Watchdog error: {e}", flush=True)

        time.sleep(CHECK_INTERVAL)


if __name__ == "__main__":
    main()
