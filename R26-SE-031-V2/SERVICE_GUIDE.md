# Service Execution & Testing Guide

This document provides instructions on how to run and test the microservices for the **R26-SE-031-V2** research project.

## 1. System Overview

The system consists of four primary microservices communicating via REST APIs:
- **C1 Monitoring (CBME)**: Processes behavioral telemetry into MBSV. (Port 8011)
- **C2 Visual (AVLI)**: Contextual bandit for typography adaptation. (Port 8014)
- **C3 Content (PLCE)**: Personalized learning content engine (BKT). (Port 8012)
- **C4 Intervention (IIGE)**: Intelligent guidance and phonological intervention. (Port 8013)

## 2. Prerequisites

### Environment Setup
1. **Python 3.10+**: Ensure Python is installed.
2. **Dependencies**: Install the shared and individual dependencies.
   ```bash
   pip install -r monitoring-service-v2/requirements.txt
   pip install -r visual-service-v2/requirements.txt
   pip install -r content-service-v2/requirements.txt
   pip install -r intervention-service-v2/requirements.txt
   pip install python-dotenv motor motor-asyncio httpx fastapi uvicorn
   ```
3. **Configuration**: Create a `.env` file in the root directory (based on `.env.example` if available).
   - Ensure `MONGO_URI` is set to a valid MongoDB Atlas connection string.
   - Ensure service ports are correctly defined.

## 3. How to Run Services

### A. Unified Execution (Recommended)
Use the master runner script to start all services concurrently.
```bash
python run_all_services.py
```
- **Logs**: Captured in the `./logs/` directory.
- **Process**: Services run as subprocesses. Use `Ctrl+C` to terminate all.

### B. Individual Execution
To run a specific service for debugging, navigate to its directory and run `main.py`.

**C1 Monitoring**:
```bash
cd monitoring-service-v2
python main.py
```

**C2 Visual**:
```bash
cd visual-service-v2
python main.py
```

**C3 Content**:
```bash
cd content-service-v2
python main.py
```

**C4 Intervention**:
```bash
cd intervention-service-v2
python main.py
```

## 4. Model Training (Prerequisite)

Before running the services for the first time or if you update the datasets, you must train the machine learning models.

```bash
cd scripts
python run_all_training.py
```
This will generate the `.pkl` files in the `models/` directory for C1 (LightGBM/RF) and C2 (LinUCB).

## 5. How to Test Services

### A. Health Checks
Verify that services are alive and reachable.
```powershell
# PowerShell
Invoke-RestMethod -Uri http://localhost:8011/health
Invoke-RestMethod -Uri http://localhost:8012/health
Invoke-RestMethod -Uri http://localhost:8013/health
Invoke-RestMethod -Uri http://localhost:8014/health
```

### B. Module Smoke Tests
Validate the core logic (Welford, BKT, SM-2, LinUCB) without requiring a running database or active services.
```bash
python smoke_test.py
```

### C. Integration Tests
Run a full test suite that validates inter-service communication, schema compliance, and end-to-end telemetry processing.
**Note**: Requires services to be configured (MongoDB access).
```bash
python integration_test.py
```

### D. Manual API Testing
You can use the Postman MCP or any REST client (like Insomnia or Curl) to test specific endpoints defined in the `main.py` of each service.

**Example: Test Monitoring Telemetry**
```bash
curl -X POST http://localhost:8011/api/v1/telemetry \
     -H "Content-Type: application/json" \
     -d '{"student_id":"test_user","session_id":"sess_001","hesitation_ms":3000,"correction_rate":0.5}'
```

---
*Created for R26-SE-031-V2 Academic Implementation*
