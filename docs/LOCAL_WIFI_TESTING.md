# Local Wi-Fi testing

This starts C5, C1 and C2 on the computer. A physical Android device on the
same Wi-Fi can complete activities, while parent and therapist dashboards read
the same database. C4 is not started by this flow.

## Setup

1. Run `ipconfig` and copy the Wi-Fi adapter IPv4 address.
2. Copy `app/frontend/.env.wifi.example` to `app/frontend/.env` and set `API_HOST`.
   Keep `DATA_ORIGIN=observed` for actual student sessions; set it to
   `synthetic` only for generated/test recordings so both C1 and C2 carry the
   same provenance label.
3. Put `MONGODB_URL`, `MONGODB_DB_NAME`, and `JWT_SECRET_KEY` in
   `app/backend/api/.env`. Use the same database and JWT secret configured on
   Render; the launcher passes them to local C1 and C2.
4. The example Flutter config uses Render for login and account/profile APIs,
   and the computer's LAN address for local dashboards, telemetry, and speech.
   Render and local services must share the same MongoDB database and JWT key.
5. Allow Python through Windows Firewall on private networks.
6. In the backend virtual environment, install the C2 JWT decoder if needed:

   ```powershell
   python -m pip install PyJWT
   ```

## Run

```powershell
python start_services.py --local-c1c2
```

Service ports are C5 `8015`, C1 `8025`, and C2 `8020`. Verify from the phone:

```text
http://<LAN_IP>:8015/health
http://<LAN_IP>:8025/health
http://<LAN_IP>:8020/health
```

After the Whisper model finishes loading, check `http://<LAN_IP>:8020/ready`.
It should report `ready: true`; while the model is loading it returns `503`.

Then run Flutter from `app/frontend` with `flutter run` (debug mode permits the
local HTTP URLs). Register a parent,
create a child, complete touch and reading activities, and check the parent
dashboard. Connect a separate therapist account to the child and verify the
same sessions in the therapist dashboard.

Do not use `localhost` or `127.0.0.1` on the phone. All records are scoped by
the authenticated account and `student_id`.
