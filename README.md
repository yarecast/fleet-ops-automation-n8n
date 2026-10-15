# Fleet Ops Automation with n8n

<div align="center">

![n8n](https://img.shields.io/badge/n8n-2.39.10-orange?style=flat-square&logo=n8n)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16.15-blue?style=flat-square&logo=postgresql)
![Ollama](https://img.shields.io/badge/Ollama-llama3.2%3A3b-green?style=flat-square&logo=ollama)
![Docker Compose](https://img.shields.io/badge/Docker-Compose-29B6F6?style=flat-square&logo=docker)

*“The AI proposes, the rules decide, and people review what is unclear.”*

</div>

---

## 1. What This Is and What It Is For (No Technical Jargon)

Picture a trucking company whose vehicles leave every day to deliver goods to customers. In many companies like this, the office work is still done by hand: someone checks where each truck is, someone enters the invoices, someone compares the payments received against what was billed, and someone builds a daily Excel report. It is slow and mistakes happen.

This project shows how that work can be automated with four "robots" that run on their own, without anyone having to watch over them:

1. **Tracking Robot**  
   When a truck arrives at a place or leaves it, the system receives the notice, updates the trip, and works out whether it is running late. If the delay is significant, it sends a Telegram message to the team.

2. **Billing Robot**  
   Every morning it looks at the trips that were already delivered, prepares the invoices that are missing, and compares them with the payments received. If everything matches, the invoice is marked as reconciled. If something does not add up (an incomplete payment, several possible payments, or no payment at all), the robot does **NOT** decide by itself: it sends the case to a review list for a person to resolve, and sends an alert on Telegram.

3. **Reporting Robot**  
   Every morning it builds an Excel file with a summary of the operation (on-time and late trips, deliveries not yet invoiced, customer waiting times) and sends it on Telegram.

4. **Question Assistant**  
   A team member types a question in plain language, for example *"which trips are running late"*, and the system answers with real data. Artificial intelligence is used only to understand the question. The AI does not write database queries, cannot change anything, and when it is not sure what was asked, it hands the case to a person.

On top of that, the system looks after itself: it raises an alert when something fails, keeps a log of what happens without storing sensitive information, and automatically deletes old data.

> **IMPORTANT:** All data is invented (synthetic) and nothing connects to a real system. This is a technical demo that is free to run and works entirely on an ordinary computer.

---

## 2. Architecture

Everything runs on a single machine with Docker Compose:

* **n8n 2.39.10 (Community Edition):** Orchestrates the workflows. Listens only on `127.0.0.1:5678`.
* **PostgreSQL 16.15:** Two databases, one for n8n and one for the business data (`fleetops`).
* **Ollama 0.35.1** (installed natively on Windows) running the `llama3.2:3b` model. n8n reaches it at `http://host.docker.internal:11434`.
* **Telegram:** Channel for alerts and for delivering the report.
* **Simulated external systems (mocks):** The GPS provider (Samsara-like) is simulated with two n8n workflows. The transport ERP (TMW-like) and the accounting system (Sage-like) are represented by the `tmw` and `sage` schemas in the database.

### `fleetops` Database Schema
* **Schema `tmw`:** operators, equipment, orders, trips.
* **Schema `sage`:** invoices, receivables.
* **Schema `ops`:** inbound_events, review_queue, logs.
* **Schema `ai_views`:** Read-only views (`v_trips`, `v_invoices`, `v_delivered_unbilled`, `v_review_queue`) with `security_barrier`. This is the only thing the AI layer can read.
* **Roles:** `fleetops_app` (read/write, used by workflows) and `fleetops_readonly` (SELECT on `ai_views` only).

---

## 3. Workflows (`workflows/` folder, one JSON file per n8n id)

* **`flujo-a-track-and-trace` (`K85vZ7ZJUbqk6BjO`)**  
  Webhook `POST /webhook/ops/inbound-events`. Receives signed geofence events. Validates the HMAC-SHA256 signature (constant-time comparison), freshness (300 s tolerance against replay), schema, and a 10 KB size limit. Idempotent by `event_id`. Updates the trip, sends a Telegram alert, and writes to `ops.logs`. Rejections return generic 401 or 400 responses, and the real reason is kept only in `ops.logs`.

* **`flujo-b-billing-reconciliation` (`flujoBBillingRec01`)**  
  Daily at 07:00 (and manual). 100% set-based SQL: creates draft invoices for delivered trips without an invoice and reconciles them against receivables (same customer, currency, and amount). Outcomes: `matched`, `partial`, `ambiguous`, or `unmatched`. Anything that is not matched goes to `ops.review_queue` and triggers an alert. Idempotent.

* **`flujo-c-daily-report` (`flujoCDailyReport01`)**  
  Daily at 08:00 (and manual). One query builds the data; a Code node generates a 4-sheet `.xlsx` workbook (*Resumen*, *Viajes tarde*, *Sin facturar*, *Espera por cliente*) which is sent on Telegram.

* **`flujo-d-ask` (`flujoDAskAi0001`)**  
  Webhook `POST /webhook/ops/ask` with an `X-Ask-Secret` header. Question of 1 to 300 characters (the assistant works with questions written in Spanish). The model classifies the question into a closed catalog of intents (`trips_by_status`, `late_trips`, `trip_detail`, `unbilled_deliveries`, `invoices_by_reconciliation`, `pending_reviews`, `unknown`). The model never writes SQL: each intent maps to a fixed, parameterized query running with the read-only role. If the model output is invalid, has low confidence, or a parameter does not appear literally in the question, the case goes to human review (`HTTP 202`). The answer always includes the interpretation that was used. Calls to Ollama retry with exponential backoff (2 and 4 seconds).

* **`global-error-handler` (`globalErrorHandler01`)**  
  Error Workflow for all others. Writes the error to `ops.logs` and sends a Telegram alert containing only the workflow name, node, and execution id (no error message and no data).

* **`ops-data-retention` (`opsDataRetention01`)**  
  Daily at 03:00. Deletes the question text stored in `review_queue` (after 14 days or once resolved) and purges `ops.logs` after 90 days.

* **`samsara-mock-locations` & `samsara-mock-geofence-events`**  
  Simulate the GPS provider. The second one builds a geofence event, signs it (HMAC over `"v1:<timestamp>:<body>"`), and sends it to Flujo A. Run manually; has no publishable trigger.

---

## 4. Security and Privacy

* Secrets live only in `.env` (never in git). `.env.example` contains placeholders. Exported workflows do not include credentials.
* n8n is exposed only on `127.0.0.1`.
* HMAC signature with `timingSafeEqual`, a 300 s anti-replay window, size limit, and idempotency.
* Generic errors toward the client; the real reason goes to `ops.logs`, which has no free-text column (codes only).
* AI layer: closed list of intents, deterministic validation, parameter grounding check, read-only role, and `security_barrier` views. Confidence reported by the model is treated as a weak signal, not as a defense.
* n8n retention: successful executions are not stored; failed ones are kept for 24 hours. This prevents storing headers that carry secrets.
* All data is synthetic and flagged with `is_synthetic`.

---

## 5. How to Run It

**Requirements:** Windows 10/11, Docker Desktop with WSL2, PowerShell, Ollama, and your own Telegram bot. Runs comfortably with ~3.5 GB of RAM available to Docker.

1. **Clone the repository** and copy `.env.example` to `.env`. Fill in the values with your own secrets (never commit `.env`). Key variables include:
   `POSTGRES_ADMIN_*`, `FLEETOPS_DB_NAME`, `FLEETOPS_APP_*`, `FLEETOPS_RO_*`, `N8N_DB_*`, `N8N_ENCRYPTION_KEY`, `SAMSARA_MOCK_SHARED_SECRET`, `NODE_FUNCTION_ALLOW_BUILTIN`, `NODE_FUNCTION_ALLOW_EXTERNAL`, `N8N_BLOCK_ENV_ACCESS_IN_NODE`, `SAMSARA_MOCK_INGESTION_URL`, `ETA_DEVIATION_ALERT_THRESHOLD_MIN`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `ASK_SHARED_SECRET`, `ASK_CONFIDENCE_THRESHOLD`, and `EXECUTIONS_DATA_*` settings.

2. **Start the containers:**
   ```bash
   docker compose up -d
   ```
   *(Scripts in `sql/init` create roles, schemas, and views on first run).*  
   After modifying `.env`, apply changes using:
   ```bash
   docker compose up -d --force-recreate n8n
   ```

3. **Pull the AI model:**
   ```bash
   ollama pull llama3.2:3b
   ```

4. **Configure n8n:**  
   Open `http://127.0.0.1:5678`, create the owner account, and set up three credentials:
   * Postgres with `fleetops_app`
   * Postgres with `fleetops_readonly`
   * Telegram (with your bot token)

5. **Import workflows:**
   ```bash
   docker compose cp workflows/<file>.json n8n:/tmp/x.json
   docker compose exec -T n8n n8n import:workflow --input=/tmp/x.json
   ```
   *Note: Workflows reference credentials by ID. If your credential IDs differ, reassign them on each node from the UI.*

6. **Activate workflows in the UI:**  
   Enable `flujo-a`, `flujo-b`, `flujo-c`, `flujo-d`, `ops-data-retention`, and `samsara-mock-locations`. Each workflow is pre-configured with its Error Workflow set to `global-error-handler`.

> **⚠️ Fixed Rule:** Never run `docker compose down -v` (it deletes all persistent data).

### Quick Test of the Assistant (PowerShell)
1. Save the request body to a file without BOM (e.g., `file.json`):
   ```json
   {"question": "que viajes van tarde"}
   ```
2. Execute via `curl.exe`:
   ```powershell
   curl.exe -s -X POST http://127.0.0.1:5678/webhook/ops/ask \
     -H "Content-Type: application/json" \
     -H "X-Ask-Secret: <value of ASK_SHARED_SECRET in .env>" \
     --data-binary "@file.json"
   ```
   *The first call takes about 24 s (model load); subsequent calls take ~8 s.*

### Re-export Workflows to Git
To back up workflows from n8n to git (includes an automated secrets check):
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\export-workflows.ps1
```

---

## 6. Repository Layout

```text
├── sql/
│   ├── init/               # Roles, schemas, and security views
│   ├── flujo-b/            # Draft invoices and reconciliation queries
│   ├── flujo-c/            # Daily report queries
│   └── flujo-d/            # Closed-catalog queries and outcome logging
├── scripts/
│   ├── flujo-c/            # Excel workbook builder (.xlsx)
│   ├── flujo-d/            # Request validation, intent parsing, and formatting
│   └── ops/                # Workflow export script
├── workflows/              # Exported n8n workflows (credentials scrubbed)
├── docker-compose.yml      # Container orchestration
└── .env.example            # Environment variable templates
```

---

## 7. Known Limitations

* **Demo Nature:** Uses synthetic data and simulated external systems; no real production integration with Samsara, TMW, or Sage.
* **Reconciliation Edge Case:** Two invoices from the same customer with the exact same amount competing for the same receivable in a single run could both end up reconciled.
* **Assistant Interpretation:** A wrong but authorized reading of a read-only view is technically possible (e.g., interpreting a nonsense status as `in_transit`). This is mitigated by always displaying the system's interpretation in the response.
* **n8n Parser Behavior:** If malformed JSON arrives with `Content-Type: application/json`, the built-in n8n parser responds with a `422` detail message before the workflow executes; this cannot be trapped inside the workflow.
* **Telegram Retries:** n8n's native retries use a fixed wait interval; a retried Telegram message might duplicate if the first delivery succeeded but the network response was lost.
* **Report Window:** The daily report is cumulative with no custom date filter window.
* **PostgreSQL Version Pinning:** PostgreSQL 16 sits outside n8n 2.x's official range (compatibility support only), but was pinned intentionally by design.
* **Model Latency:** The local 3B parameter model runs slowly on lower-end hardware configurations.
