@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"
set "PYTHONIOENCODING=utf-8"
set "DEFAULT_CSV=%~dp0data\dataset.csv"

if "%~1"=="" goto usage

if /i "%~1"=="demo" goto demo
if /i "%~1"=="train" goto train
if /i "%~1"=="test" goto test
if /i "%~1"=="pipeline" goto pipeline
if /i "%~1"=="all" goto pipeline
goto usage

:usage
echo.
echo  Model1 — one script
echo.
echo    run_model1.bat demo              Built-in Sinhala paragraph (no CSV^)
echo    run_model1.bat train [csv]     Train (default: data\dataset.csv^)
echo    run_model1.bat test [csv]      Evaluate on labelled CSV (default: data\dataset.csv^)
echo    run_model1.bat pipeline [csv]  Train then test (default: data\dataset.csv^)
echo.
echo  Optional CSV: full path, or drag file onto script after the command word.
echo  Second arg for train: output dir (default ml\model1^)
echo  Second arg for test: artifacts dir (default ml\model1^)
echo.
exit /b 0

:demo
python ml\training\predict_paragraph_model1.py
exit /b %errorlevel%

:setcsv
set "CSV=%DEFAULT_CSV%"
if not "%~2"=="" set "CSV=%~2"
exit /b 0

:train
call :setcsv %*
if not exist "!CSV!" (
  echo Missing: !CSV!
  echo Put your CSV in data\dataset.csv or pass: run_model1.bat train "C:\path\to\file.csv"
  pause
  exit /b 1
)
echo Training: !CSV!
if "%~3"=="" (
  python ml\training\train_model1.py --csv "!CSV!"
) else (
  python ml\training\train_model1.py --csv "!CSV!" --out-dir "%~3"
)
if errorlevel 1 pause
exit /b %errorlevel%

:test
call :setcsv %*
if not exist "!CSV!" (
  echo Missing: !CSV!
  pause
  exit /b 1
)
echo Testing: !CSV!
if "%~3"=="" (
  python ml\training\test_model1.py --csv "!CSV!" --artifacts ml\model1
) else (
  python ml\training\test_model1.py --csv "!CSV!" --artifacts "%~3"
)
if errorlevel 1 pause
exit /b %errorlevel%

:pipeline
set "CSV=%DEFAULT_CSV%"
if not "%~2"=="" set "CSV=%~2"
if not exist "!CSV!" (
  echo Missing: !CSV!
  echo Put CSV as data\dataset.csv or: run_model1.bat pipeline "C:\path\to\file.csv"
  pause
  exit /b 1
)
echo [1/2] Training: !CSV!
python ml\training\train_model1.py --csv "!CSV!"
if errorlevel 1 ( echo Training failed. & pause & exit /b 1 )
echo.
echo [2/2] Testing: !CSV!
python ml\training\test_model1.py --csv "!CSV!" --artifacts ml\model1
if errorlevel 1 ( echo Test failed. & pause & exit /b 1 )
echo Done. Artifacts: ml\model1\
pause
exit /b 0
