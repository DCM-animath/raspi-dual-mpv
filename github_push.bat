@echo off
title Upload Dual MPV ke GitHub
color 0A

echo ============================================
echo     UPLOAD PROJECT DUAL MPV KE GITHUB
echo ============================================
echo.

:: ── KONFIGURASI — sesuaikan di sini ──────────────────────
set GITHUB_USER=DCM-animath
set REPO_NAME=raspi-dual-mpv
:: ──────────────────────────────────────────────────────────

:: Cek git tersedia
where git >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Git tidak ditemukan.
    echo         Download di: https://git-scm.com/download/win
    pause
    exit /b 1
)

:: Pindah ke folder script ini
cd /d "%~dp0"

:: Cek folder root/ ada
if not exist "root\" (
    echo [ERROR] Folder 'root\' tidak ditemukan.
    echo         Pastikan extract root_improved.zip di sini dulu.
    pause
    exit /b 1
)

echo [STEP 1] Membuat file README.md...
(
echo # Raspi Dual MPV Player
echo.
echo Sistem dual video player untuk Raspberry Pi 5 menggunakan MPV.
echo Memutar 2 video secara sinkron di 2 monitor via HDMI.
echo.
echo ## Struktur
echo - `root/boot/firmware/splash/` — script MPV dan GPIO
echo - `root/etc/systemd/system/` — systemd service files
echo.
echo ## Install ke RPi
echo ```bash
echo curl -fsSL https://raw.githubusercontent.com/%GITHUB_USER%/%REPO_NAME%/main/install.sh ^| bash
echo ```
echo.
echo ## Kebutuhan
echo - Raspberry Pi 5
echo - 2 monitor HDMI
echo - 5 tombol GPIO ^(pin 17, 27, 22, 23, 24^)
echo - 12 file video: `1-left.mp4` sampai `6-right.mp4`
) > README.md
echo [OK] README.md dibuat

echo.
echo [STEP 2] Init git repo...
if not exist ".git\" (
    git init
    echo [OK] Git diinisialisasi
) else (
    echo [OK] Git sudah ada, skip init
)

echo.
echo [STEP 3] Set remote origin...
git remote remove origin 2>nul
git remote add origin https://github.com/%GITHUB_USER%/%REPO_NAME%.git
echo [OK] Remote: https://github.com/%GITHUB_USER%/%REPO_NAME%.git

echo.
echo [STEP 4] Stage semua file...
git add .
git status --short
echo [OK] File di-stage

echo.
echo [STEP 5] Commit...
git commit -m "deploy: initial upload dual MPV project" 2>nul || (
    echo [INFO] Tidak ada perubahan baru, skip commit
)

echo.
echo [STEP 6] Push ke GitHub...
echo.
echo [INFO] Pastikan repo sudah dibuat dulu di GitHub:
echo        https://github.com/new
echo        Nama repo: %REPO_NAME%
echo        Visibility: Public
echo        Jangan centang "Add README" atau apapun
echo.
pause

git branch -M main
git push -u origin main

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ============================================
    echo  BERHASIL UPLOAD!
    echo  URL repo: https://github.com/%GITHUB_USER%/%REPO_NAME%
    echo.
    echo  Perintah install di RPi:
    echo  curl -fsSL https://raw.githubusercontent.com/%GITHUB_USER%/%REPO_NAME%/main/install.sh ^| bash
    echo ============================================
) else (
    echo.
    echo [ERROR] Push gagal. Kemungkinan penyebab:
    echo   - Repo belum dibuat di GitHub
    echo   - Username salah
    echo   - Belum login git: git config --global user.email "email@kamu.com"
    echo                      git config --global user.name "Nama Kamu"
)

echo.
pause