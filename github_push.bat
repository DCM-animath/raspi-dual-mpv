@echo off
setlocal ENABLEDELAYEDEXPANSION
title GitHub Push Helper

cd /d "%~dp0"

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Folder ini bukan repo Git.
    pause
    exit /b 1
)

for /f "delims=" %%i in ('git config --global user.name 2^>nul') do set GIT_NAME=%%i
for /f "delims=" %%i in ('git config --global user.email 2^>nul') do set GIT_EMAIL=%%i

if "%GIT_NAME%"=="" (
    set /p GIT_NAME=Masukkan git user.name:
    git config --global user.name "%GIT_NAME%"
)

if "%GIT_EMAIL%"=="" (
    set /p GIT_EMAIL=Masukkan git user.email:
    git config --global user.email "%GIT_EMAIL%"
)

for /f "delims=" %%i in ('git remote get-url origin 2^>nul') do set ORIGIN_URL=%%i
if "%ORIGIN_URL%"=="" (
    set /p ORIGIN_URL=Masukkan URL repo GitHub:
    git remote add origin "%ORIGIN_URL%" 2>nul
    if errorlevel 1 (
        git remote set-url origin "%ORIGIN_URL%"
    )
)

git add .

git diff --cached --quiet
if errorlevel 1 (
    set /p COMMIT_MSG=Masukkan commit message:
    if "!COMMIT_MSG!"=="" set COMMIT_MSG=Update project files
    git commit -m "!COMMIT_MSG!"
    if errorlevel 1 (
        echo [ERROR] Commit gagal.
        pause
        exit /b 1
    )
) else (
    echo [INFO] Tidak ada perubahan baru.
    git rev-parse --verify HEAD >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Belum ada commit sama sekali. Tambahkan file dulu lalu commit.
        pause
        exit /b 1
    )
)

git checkout -B main
if errorlevel 1 (
    echo [ERROR] Gagal membuat atau pindah ke branch main.
    pause
    exit /b 1
)

echo Pilih mode:
echo 1. Pull lalu push normal
echo 2. Force push
set /p MODE=Masukkan pilihan [1/2]:

if "%MODE%"=="1" (
    git pull origin main --allow-unrelated-histories
    if errorlevel 1 (
        echo [ERROR] Pull gagal.
        pause
        exit /b 1
    )
    git push -u origin main
    if errorlevel 1 (
        echo [ERROR] Push gagal.
        pause
        exit /b 1
    )
)

if "%MODE%"=="2" (
    git push -u origin main --force
    if errorlevel 1 (
        echo [ERROR] Force push gagal.
        pause
        exit /b 1
    )
)

if not "%MODE%"=="1" if not "%MODE%"=="2" (
    echo [ERROR] Pilihan tidak valid.
    pause
    exit /b 1
)

echo [SUCCESS] Selesai.
pause