@echo off
REM Runs the Reading Intervention Flutter app on an Android device or emulator.
REM Robust against PATH-not-refreshed problems.

setlocal
cd /d "%~dp0"

REM 1) If flutter is already on PATH, use it directly.
where flutter >nul 2>&1
if %errorlevel% equ 0 goto :have_flutter

REM 2) Otherwise probe well-known install locations.
set "FLUTTER_BIN="
if exist "C:\src\flutter\flutter\bin\flutter.bat" set "FLUTTER_BIN=C:\src\flutter\flutter\bin"
if exist "C:\src\flutter\bin\flutter.bat"          set "FLUTTER_BIN=C:\src\flutter\bin"
if exist "C:\flutter\bin\flutter.bat"              set "FLUTTER_BIN=C:\flutter\bin"
if exist "%USERPROFILE%\flutter\bin\flutter.bat"   set "FLUTTER_BIN=%USERPROFILE%\flutter\bin"
if exist "%LOCALAPPDATA%\flutter\bin\flutter.bat"  set "FLUTTER_BIN=%LOCALAPPDATA%\flutter\bin"

if "%FLUTTER_BIN%"=="" (
  echo.
  echo ERROR: flutter not found on PATH and not in any known location.
  echo Install Flutter from https://docs.flutter.dev/get-started/install/windows
  echo.
  endlocal & exit /b 1
)

set "PATH=%FLUTTER_BIN%;%PATH%"
echo Using Flutter from: %FLUTTER_BIN%

:have_flutter

echo.
echo === Reading Intervention (Android) ==================================
echo  Make sure an Android Emulator is running, or an Android phone
echo  is plugged in with USB Debugging enabled.
echo =====================================================================
echo.

REM Run on android. If multiple devices are found, Flutter will prompt you to choose.
flutter run -d android

endlocal
