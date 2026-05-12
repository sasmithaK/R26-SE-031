@echo off
REM Starts the intervention-service FastAPI backend on http://127.0.0.1:8000
REM Hot-reloads on file changes. Press Ctrl+C to stop.

setlocal
cd /d "%~dp0"

echo.
echo === Intervention Service ===========================================
echo  Backend will run at: http://127.0.0.1:8000
echo  Health check:        http://127.0.0.1:8000/health
echo  Stop with:           Ctrl+C
echo =====================================================================
echo.

python -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload

endlocal
