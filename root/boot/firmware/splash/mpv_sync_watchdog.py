#!/usr/bin/env python3
import subprocess
import time

CHECK_INTERVAL = 5
START_SCRIPT = "/boot/firmware/splash/start_dual.sh"


def count_mpv():
    result = subprocess.run(["pgrep", "-c", "mpv"], capture_output=True, text=True)
    try:
        return int(result.stdout.strip())
    except ValueError:
        return 0


while True:
    if count_mpv() < 2:
        subprocess.run(["pkill", "-f", "mpv"], check=False)
        subprocess.Popen(["bash", START_SCRIPT])
    time.sleep(CHECK_INTERVAL)