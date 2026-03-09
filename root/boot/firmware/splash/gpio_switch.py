#!/usr/bin/env python3
"""
gpio_switch.py
Handles button input via GPIO to switch video sets on dual MPV players.
Writes current mode to /tmp/mpv-mode so mpv_sync_watchdog.py can coordinate.
"""

import json
import os
import socket
import sys
import time
import signal
from datetime import timedelta

import gpiod
from gpiod.line import Direction, Bias, Value

# ── Socket paths ────────────────────────────────────────────────────────────
LEFT_SOCK  = "/tmp/mpv-left.sock"
RIGHT_SOCK = "/tmp/mpv-right.sock"

# File untuk koordinasi mode dengan watchdog
MODE_FILE  = "/tmp/mpv-mode"   # isi: "idle" atau "oneshot"

# ── Konfigurasi set video ────────────────────────────────────────────────────
IDLE_SET = 1
FILES = {
    1: ("/boot/firmware/splash/1-left.mp4", "/boot/firmware/splash/1-right.mp4"),
    2: ("/boot/firmware/splash/2-left.mp4", "/boot/firmware/splash/2-right.mp4"),
    3: ("/boot/firmware/splash/3-left.mp4", "/boot/firmware/splash/3-right.mp4"),
    4: ("/boot/firmware/splash/4-left.mp4", "/boot/firmware/splash/4-right.mp4"),
    5: ("/boot/firmware/splash/5-left.mp4", "/boot/firmware/splash/5-right.mp4"),
    6: ("/boot/firmware/splash/6-left.mp4", "/boot/firmware/splash/6-right.mp4"),
}

# Mapping: GPIO pin → set number
# 5 tombol untuk set 2–6, set 1 adalah idle (auto-return)
BUTTON_TO_SET = {
    17: 2,
    27: 3,
    22: 4,
    23: 5,
    24: 6,
}
BUTTONS = list(BUTTON_TO_SET.keys())

# ── Timing & threshold ───────────────────────────────────────────────────────
SOCKET_WAIT_TIMEOUT    = 30    # detik tunggu socket MPV muncul
SAMPLE_INTERVAL        = 0.01  # 10ms polling interval
STABLE_SAMPLES         = 4     # jumlah sample stabil sebelum dianggap pressed
BOOT_IGNORE_SECONDS    = 1.0   # abaikan input saat baru booting
RELEASE_STABLE_SECONDS = 0.3   # durasi stabil release sebelum siap

RETURN_MARGIN          = 0.08  # detik sebelum akhir video untuk trigger return
IDLE_RESYNC_MARGIN     = 0.06  # margin sebelum loop end untuk resync
IDLE_MAX_DRIFT         = 0.08  # drift (detik) maksimal sebelum resync idle
IDLE_RESYNC_GUARD      = 1.0   # cooldown setelah switch sebelum mulai resync idle

LOAD_SETTLE_MS         = 150   # waktu tunggu (ms) setelah loadfile sebelum unpause


# ── Helper: tulis mode ke file ───────────────────────────────────────────────
def write_mode(mode: str):
    """Tulis mode saat ini ke MODE_FILE agar watchdog bisa baca."""
    try:
        with open(MODE_FILE, "w") as f:
            f.write(mode)
    except Exception:
        pass


# ── Signal handler ───────────────────────────────────────────────────────────
def cleanup(*_):
    try:
        os.remove(MODE_FILE)
    except Exception:
        pass
    sys.exit(0)


signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGINT, cleanup)


# ── GPIO chip detection ──────────────────────────────────────────────────────
def find_chip_path():
    for path in ("/dev/gpiochip4", "/dev/gpiochip0"):
        if os.path.exists(path):
            print(f"[INFO] GPIO chip: {path}", flush=True)
            return path
    raise FileNotFoundError("GPIO chip tidak ditemukan")


# ── Socket wait ──────────────────────────────────────────────────────────────
def wait_for_sockets():
    deadline = time.time() + SOCKET_WAIT_TIMEOUT
    while time.time() < deadline:
        if os.path.exists(LEFT_SOCK) and os.path.exists(RIGHT_SOCK):
            print("[INFO] Socket MPV siap", flush=True)
            return
        time.sleep(0.2)
    raise TimeoutError("Socket MPV tidak muncul dalam waktu yang ditentukan")


# ── MPV IPC ──────────────────────────────────────────────────────────────────
def mpv_cmd(sock_path: str, command: list):
    """Kirim satu perintah IPC ke MPV. Return respons dict atau None."""
    payload = json.dumps({"command": command}) + "\n"
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(1.0)
    try:
        s.connect(sock_path)
        s.sendall(payload.encode("utf-8"))
        try:
            data = s.recv(4096)
            if data:
                return json.loads(data.decode("utf-8", errors="ignore"))
        except Exception:
            return None
    except Exception:
        return None
    finally:
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


def set_prop(sock_path: str, prop: str, value):
    mpv_cmd(sock_path, ["set_property", prop, value])


def set_pause_both(state: bool):
    """Pause/unpause kedua player — kirim berurutan secepat mungkin."""
    set_prop(LEFT_SOCK,  "pause", state)
    set_prop(RIGHT_SOCK, "pause", state)


def set_loop_both(value):
    set_prop(LEFT_SOCK,  "loop-file", value)
    set_prop(RIGHT_SOCK, "loop-file", value)


def seek_zero_both():
    mpv_cmd(LEFT_SOCK,  ["seek", 0, "absolute", "exact"])
    mpv_cmd(RIGHT_SOCK, ["seek", 0, "absolute", "exact"])


# ── Load pair ────────────────────────────────────────────────────────────────
def load_pair(set_num: int, loop_forever: bool) -> bool:
    """
    Load pasangan video kiri/kanan ke MPV.
    Pause dulu, load, tunggu settle, baru play bersama.
    Return True jika berhasil.
    """
    left_path, right_path = FILES[set_num]

    if not os.path.exists(left_path):
        print(f"[WARN] File tidak ada: {left_path}", flush=True)
        return False
    if not os.path.exists(right_path):
        print(f"[WARN] File tidak ada: {right_path}", flush=True)
        return False

    loop_value = "inf" if loop_forever else "no"
    mode_label = "IDLE" if loop_forever else "ONESHOT"

    # 1. Pause dulu
    set_pause_both(True)

    # 2. Set loop sebelum load
    set_loop_both(loop_value)

    # 3. Load file (berurutan secepat mungkin)
    mpv_cmd(LEFT_SOCK,  ["loadfile", left_path,  "replace"])
    mpv_cmd(RIGHT_SOCK, ["loadfile", right_path, "replace"])

    # 4. Tunggu decoder settle sebelum play bersamaan
    time.sleep(LOAD_SETTLE_MS / 1000.0)

    # 5. Seek ke awal & play bersamaan
    seek_zero_both()
    set_pause_both(False)

    print(
        f"[INFO] Set {set_num} -> {os.path.basename(left_path)} | "
        f"{os.path.basename(right_path)} | {mode_label}",
        flush=True,
    )
    return True


# ── Button reading ───────────────────────────────────────────────────────────
def get_pressed_pins(request) -> list:
    return [pin for pin in BUTTONS if request.get_value(pin) is Value.INACTIVE]


def read_single_pressed(request):
    active = get_pressed_pins(request)
    return active[0] if len(active) == 1 else None


def wait_boot_release(request):
    """Tunggu semua tombol release stabil sebelum mulai terima input."""
    print("[INFO] Warmup boot...", flush=True)
    time.sleep(BOOT_IGNORE_SECONDS)

    need_samples = max(1, int(RELEASE_STABLE_SECONDS / SAMPLE_INTERVAL))
    stable_release = 0

    print("[INFO] Menunggu semua tombol release...", flush=True)
    while True:
        active = get_pressed_pins(request)
        if len(active) == 0:
            stable_release += 1
        else:
            stable_release = 0
            print(f"[INFO] Tombol masih aktif saat boot: {active}", flush=True)

        if stable_release >= need_samples:
            print("[INFO] Tombol release. Input siap.", flush=True)
            return

        time.sleep(SAMPLE_INTERVAL)


# ── Oneshot selesai? ─────────────────────────────────────────────────────────
def oneshot_finished() -> bool:
    """Return True jika salah satu/kedua player sudah mendekati akhir video."""
    for sock in (LEFT_SOCK, RIGHT_SOCK):
        if get_prop(sock, "idle-active") is True:
            return True

    lt = get_prop(LEFT_SOCK,  "playback-time")
    rt = get_prop(RIGHT_SOCK, "playback-time")
    ld = get_prop(LEFT_SOCK,  "duration")
    rd = get_prop(RIGHT_SOCK, "duration")

    if None in (lt, rt, ld, rd):
        return False

    lt, rt, ld, rd = float(lt), float(rt), float(ld), float(rd)
    return lt >= (ld - RETURN_MARGIN) or rt >= (rd - RETURN_MARGIN)


# ── Main ─────────────────────────────────────────────────────────────────────
def main():
    chip_path = find_chip_path()
    wait_for_sockets()

    config = {
        pin: gpiod.LineSettings(
            direction=Direction.INPUT,
            bias=Bias.PULL_UP,
            debounce_period=timedelta(milliseconds=10),
        )
        for pin in BUTTONS
    }

    current_set  = IDLE_SET
    current_mode = "idle"
    last_switch_time = 0.0

    last_sample  = None
    stable_count = 0
    handled_pin  = None

    with gpiod.request_lines(
        chip_path,
        consumer="dualmp4-gpio",
        config=config,
    ) as request:
        print("[INFO] GPIO watcher aktif", flush=True)

        # Load idle set awal, tulis mode ke file
        load_pair(IDLE_SET, loop_forever=True)
        write_mode("idle")
        wait_boot_release(request)

        while True:
            now = time.time()
            pin = read_single_pressed(request)

            # Debounce software tambahan di atas hardware debounce gpiod
            if pin == last_sample:
                stable_count += 1
            else:
                last_sample  = pin
                stable_count = 1

            if pin is None:
                handled_pin = None

            elif stable_count >= STABLE_SAMPLES and handled_pin != pin:
                target_set = BUTTON_TO_SET[pin]
                print(f"[DEBUG] GPIO{pin} -> set {target_set}", flush=True)

                if load_pair(target_set, loop_forever=False):
                    current_set  = target_set
                    current_mode = "oneshot"
                    last_switch_time = now
                    write_mode("oneshot")

                handled_pin = pin

            # Cek apakah oneshot selesai → kembali ke idle
            if current_mode == "oneshot" and oneshot_finished():
                if load_pair(IDLE_SET, loop_forever=True):
                    current_set  = IDLE_SET
                    current_mode = "idle"
                    last_switch_time = time.time()
                    write_mode("idle")

            time.sleep(SAMPLE_INTERVAL)


if __name__ == "__main__":
    main()
