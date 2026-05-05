@echo off
echo Starting Monitoring Service on port 8001...
start cmd /k "cd monitoring-service && uvicorn main:app --port 8001 --reload"

echo Starting Content Service on port 8002...
start cmd /k "cd content-service && uvicorn main:app --port 8002 --reload"

echo Starting Intervention Service on port 8003...
start cmd /k "cd intervention-service && uvicorn main:app --port 8003 --reload"

echo Starting Visual Service on port 8004...
start cmd /k "cd visual-service && uvicorn main:app --port 8004 --reload"

echo All services started in separate windows!
