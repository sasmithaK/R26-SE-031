#!/bin/bash
# MongoDB Migration Quick Start Script for macOS/Linux

echo ""
echo "================================================"
echo "   Dyslexia App - MongoDB Migration Quick Start"
echo "================================================"
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python3 is not installed"
    echo "Please install Python3 from https://www.python.org"
    exit 1
fi

# Check if MongoDB is installed
if ! command -v mongod &> /dev/null; then
    echo "ERROR: MongoDB is not installed"
    echo "Please install MongoDB from https://www.mongodb.com/try/download/community"
    exit 1
fi

echo "[1/4] Checking MongoDB service..."
# Check if MongoDB is running
if ! pgrep -x "mongod" > /dev/null; then
    echo "WARNING: MongoDB not running. Starting MongoDB..."
    
    # Try to start MongoDB
    if command -v brew &> /dev/null; then
        # macOS with Homebrew
        brew services start mongodb-community
    else
        # Linux
        sudo systemctl start mongodb || sudo service mongodb start
    fi
    
    sleep 2
    
    if ! pgrep -x "mongod" > /dev/null; then
        echo "ERROR: Could not start MongoDB"
        echo "Please start MongoDB manually"
        exit 1
    fi
fi
echo "✓ MongoDB service is running"

echo ""
echo "[2/4] Installing Python dependencies..."
cd content-service
pip3 install -r requirements.txt
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install dependencies"
    exit 1
fi
echo "✓ Dependencies installed"

echo ""
echo "[3/4] Seeding MongoDB with data..."
python3 seed_mongodb.py
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to seed MongoDB"
    echo "Check MongoDB is running and accessible at mongodb://localhost:27017"
    exit 1
fi
echo "✓ Data seeded successfully"

echo ""
echo "[4/4] Starting backend service..."
echo ""
echo "Backend will start on http://127.0.0.1:5000"
echo "Press Ctrl+C to stop the server when done"
echo ""

python3 -m uvicorn main:app --reload --port 5000
