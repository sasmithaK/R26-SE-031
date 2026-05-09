@echo off
REM MongoDB Migration Quick Start Script for Windows

echo.
echo ================================================
echo   Dyslexia App - MongoDB Migration Quick Start
echo ================================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python from https://www.python.org
    pause
    exit /b 1
)

echo [1/4] Checking MongoDB service...
net start MongoDB >nul 2>&1
if errorlevel 1 (
    echo WARNING: MongoDB service not running. Starting MongoDB...
    net start MongoDB
    if errorlevel 1 (
        echo ERROR: Could not start MongoDB service
        echo Please start MongoDB manually or check installation
        pause
        exit /b 1
    )
)
echo ✓ MongoDB service is running

echo.
echo [2/4] Installing Python dependencies...
cd content-service
pip install -r requirements.txt
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)
echo ✓ Dependencies installed

echo.
echo [3/4] Seeding MongoDB with data...
python seed_mongodb.py
if errorlevel 1 (
    echo ERROR: Failed to seed MongoDB
    echo Check MongoDB is running and accessible at mongodb://localhost:27017
    pause
    exit /b 1
)
echo ✓ Data seeded successfully

echo.
echo [4/4] Starting backend service...
echo.
echo Backend will start on http://127.0.0.1:5000
echo Press Ctrl+C to stop the server when done
echo.
pause

python -m uvicorn main:app --reload --port 5000

pause
