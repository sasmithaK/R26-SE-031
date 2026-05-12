@echo off
REM Runs the Reading Intervention Flutter app in Chrome.
REM Robust against PATH-not-refreshed problems (e.g. when Cursor was open
REM before Flutter was installed). Tries common Flutter install locations
REM if `flutter` isn't on PATH.

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
  echo Or set FLUTTER_BIN env var to the folder containing flutter.bat.
  echo.
  endlocal & exit /b 1
)

set "PATH=%FLUTTER_BIN%;%PATH%"
echo Using Flutter from: %FLUTTER_BIN%

:have_flutter

echo.
echo === Reading Intervention (Flutter) ==================================
echo  Make sure the backend is running first:
echo     http://127.0.0.1:8000/health   should return 200.
echo  Stop with: q
echo  Restart:   Shift+R   (capital R)
echo  Reload:    r
echo =====================================================================
echo.

flutter run -d chrome

endlocal
