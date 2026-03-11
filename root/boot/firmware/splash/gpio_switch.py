#!/usr/bin/env python3
import subprocess
import time
from gpiozero import Button

BUTTON_PINS = [17, 27, 22, 23]
DEBOUNCE = 0.15
SCRIPT = "/boot/firmware/splash/start_dual.sh"

buttons = [Button(pin, pull_up=True, bounce_time=DEBOUNCE) for pin in BUTTON_PINS]
last_press = 0.0


def restart_dual():
    global last_press
    now = time.time()
    if now - last_press < DEBOUNCE:
        return
    last_press = now
    subprocess.run(["pkill", "-f", "mpv"], check=False)
    subprocess.Popen(["bash", SCRIPT])


for btn in buttons:
    btn.when_pressed = restart_dual

while True:
    time.sleep(1)