@echo off
setlocal ENABLEDELAYEDEXPANSION
title GitHub Push Helper

echo ==========================================
echo   GitHub Push Helper
echo ==========================================
echo.

cd /d "%~dp0"

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Folder ini bukan repo Git.
    echo Jalankan file ini dari dalam folder project Git Anda.
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

echo.
echo [INFO] Git identity:
echo user.name  = %GIT_NAME%
echo user.email = %GIT_EMAIL%
echo.

for /f "delims=" %%i in ('git remote get-url origin 2^>nul') do set ORIGIN_URL=%%i
if "%ORIGIN_URL%"=="" (
    set /p ORIGIN_URL=Masukkan URL repo GitHub:
    git remote add origin "%ORIGIN_URL%" 2>nul
    if errorlevel 1 (
        git remote set-url origin "%ORIGIN_URL%"
    )
)

echo [INFO] Remote origin = %ORIGIN_URL%
echo.

echo Pilih mode:
echo 1. Aman. Pull dulu lalu push
echo 2. Paksa. Force push ke main
echo.
set /p MODE=Masukkan pilihan [1/2]:

echo.
echo [INFO] Mengecek branch aktif...
git branch --show-current >nul 2>&1
if errorlevel 1 (
    echo [INFO] Belum ada branch aktif. Menyiapkan branch main...
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
    echo [INFO] Tidak ada perubahan baru untuk di-commit.
)

git branch -M main
if errorlevel 1 (
    echo [ERROR] Gagal set branch ke main.
    pause
    exit /b 1
)

if "%MODE%"=="1" (
    echo.
    echo [INFO] Menarik perubahan dari remote...
    git pull origin main --allow-unrelated-histories
    if errorlevel 1 (
        echo.
        echo [ERROR] Pull gagal.
        echo Biasanya karena conflict merge yang harus diselesaikan manual.
        pause
        exit /b 1
    )

    echo.
    echo [INFO] Push ke remote...
    git push -u origin main
    if errorlevel 1 (
        echo.
        echo [ERROR] Push gagal.
        pause
        exit /b 1
    )
)

if "%MODE%"=="2" (
    echo.
    echo [INFO] Force push ke remote...
    git push -u origin main --force
    if errorlevel 1 (
        echo.
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

echo.
echo [SUCCESS] Proses selesai.
pause
exit /b 0