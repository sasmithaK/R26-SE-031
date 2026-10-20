# Local Wi-Fi MVP test

1. Connect the Windows computer and Android phone to the same private Wi-Fi network. Disable mobile-data switching for the test.
2. Copy `app/frontend/example.env` to `app/frontend/.env`. Keep `ENVIRONMENT=development`; Render remains the authentication and specialist-account service.
3. In PowerShell, activate the project virtual environment and set `MONGODB_URL` and `JWT_SECRET_KEY`. They must point to the same database and use the exact JWT signing secret configured on Render.
4. Run `./start_local_network.ps1`. It prints the detected LAN address and starts ports 8015, 8020, 8025, 9016 and 9017.
5. In another terminal, run the printed Flutter command from `app/frontend`.
6. On the phone, open `http://COMPUTER_IP:8015/health`, `:8020/health`, `:8025/health`, `:9016/health` and `:9017/health` if the app cannot connect. A timeout means the Wi-Fi client-isolation or Windows Private-network firewall is blocking the port.

The local API uses the Render-issued access token. Local C1, C2, C3 and dashboards therefore need the same JWT secret and MongoDB data as Render. C4 receives C1 behavioural evidence only. C2 and C3 remain dashboard evidence and do not update C4 mastery.
