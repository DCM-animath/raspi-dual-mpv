# Raspi Dual MPV Player

Sistem dual video player untuk Raspberry Pi 5 menggunakan MPV.
Memutar 2 video secara sinkron di 2 monitor via HDMI.

## Struktur
- `root/boot/firmware/splash/` — script MPV dan GPIO
- `root/etc/systemd/system/` — systemd service files

## Install ke RPi
```bash
curl -fsSL https://raw.githubusercontent.com/DCM-animath/raspi-dual-mpv/main/install.sh | bash
```

## Kebutuhan
- Raspberry Pi 5
- 2 monitor HDMI
- 5 tombol GPIO (pin 17, 27, 22, 23, 24)
- 12 file video: `1-left.mp4` sampai `6-right.mp4`
