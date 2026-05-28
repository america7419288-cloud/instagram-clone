@echo off
REM ============================================================
REM  Instagram Clone — Production Release Build Script
REM  Run from: C:\instagram-clone\client\
REM ============================================================

echo.
echo ================================================
echo   Building Instagram Clone — PRODUCTION RELEASE
echo ================================================
echo.

REM ─── Production server URLs ─────────────────────────────────
set API_BASE_URL=https://instagram-clone-im0x.onrender.com/api/v1
set SOCKET_URL=https://instagram-clone-im0x.onrender.com

echo [1/3] Cleaning previous build...
call flutter clean

echo.
echo [2/3] Getting dependencies...
call flutter pub get

echo.
echo [3/3] Building release APK with obfuscation...
call flutter build apk --release ^
  --dart-define=API_BASE_URL=%API_BASE_URL% ^
  --dart-define=SOCKET_URL=%SOCKET_URL% ^
  --obfuscate ^
  --split-debug-info=build/debug-info ^
  --target-platform android-arm64

echo.
echo ================================================
echo   DONE! APKs are in:
echo   build\app\outputs\flutter-apk\
echo.
echo   Debug symbols saved to:
echo   build\debug-info\
echo   (Keep these for crash symbolication!)
echo ================================================
echo.

REM ─── Optional: Also build App Bundle for Play Store ─────────
echo Build App Bundle for Play Store? (Y/N)
set /p BUILD_BUNDLE=
if /i "%BUILD_BUNDLE%"=="Y" (
    echo Building App Bundle...
    call flutter build appbundle --release ^
      --dart-define=API_BASE_URL=%API_BASE_URL% ^
      --dart-define=SOCKET_URL=%SOCKET_URL% ^
      --obfuscate ^
      --split-debug-info=build/debug-info
    echo App Bundle: build\app\outputs\bundle\release\app-release.aab
)
