# AgentGuard

AgentGuard is a runtime action firewall for autonomous agents. It checks proposed tool calls before execution and chooses to allow, modify, block, or escalate them. The project includes a custom security operations dashboard and a mock email, file, and payment environment. No real accounts or production systems are connected.

## Run locally on Windows

1. Install Python 3.10 or newer.
2. From this project folder, run `start_agentguard.bat`.
3. Open [http://127.0.0.1:8001](http://127.0.0.1:8001). The interactive API docs are at `/docs`.

If the virtual environment is not present, create one and install dependencies:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

To start manually:

```powershell
$env:PYTHONPATH = (Get-Location).Path
python -m uvicorn agentguard.api:app --host 127.0.0.1 --port 8001
```

The browser dashboard is served by the same API process, so no separate Streamlit server is needed.

## Dashboard

The dashboard includes an action stream, reason codes, verdict filters, approval queue, mock environment counts, a scenario launcher, and reset control. The scenario buttons exercise:

- A safe team email draft that should be allowed.
- An injected external data transfer that should be blocked.
- A bulk file deletion that should be converted to a recoverable action.
- A vendor payment requiring a human decision.

Use **Reset demo** to restore the mock state and clear its review history.

## Architecture

```text
Agent proposal → FastAPI action gateway → schema validation → policy and provenance checks
                                                          ├─ allow → mock tool
                                                          ├─ modify → safer mock tool action
                                                          ├─ block → no tool execution
                                                          └─ escalate → approval queue → reviewed execution
                                               All decisions → SQLite audit log → dashboard
```

The agent-facing action schema is in `agentguard/schemas.py`. Policy evaluation lives in `agentguard/policies/guard.py`; mock tools are in `agentguard/tools/`; and the dashboard assets are in `dashboard/web/`.

## API endpoints

- `GET /` – AgentGuard dashboard
- `GET /health` – service status
- `GET /v1/demo/state` – mock email, file, and payment state
- `POST /v1/demo/scenarios/{scenario_name}` – execute a built-in scenario through the guard
- `POST /v1/demo/reset` – reset demo data and audit history
- `POST /v1/actions/evaluate-and-execute` – validate, decide, and optionally execute an action
- `POST /v1/actions/evaluate` – evaluate and audit an action without invoking a tool
- `GET /v1/events?run_id=run-demo` – read audit events
- `GET /v1/approvals` – list pending human approvals
- `POST /v1/approvals/{approval_id}/decision` – approve or deny a pending action

## Policy behavior

The guard uses deterministic rules and a heuristic risk score. Rules include checks for approved email domains, mock workspace paths, sensitive outbound content, bulk delete scope, and payment thresholds. The score combines impact, reversibility, sensitivity, untrusted provenance, and destination risk. It is a prototype estimate, not a guarantee.

Provenance is wrapper-based: mock sources are tagged as trusted or untrusted and associated with action values. The project does not claim to perfectly infer every influence on an agent's reasoning.

## Configuration

Copy `.env.example` to `.env` if you want to adjust settings. Common settings include:

- `PAYMENT_APPROVAL_THRESHOLD`
- `MAX_DELETE_SCOPE`
- `ALLOWED_EMAIL_DOMAINS`
- `ALLOWED_FILE_PREFIXES`
- Optional `IBM_WATSONX_*` settings

IBM integrations are disabled by default. Do not commit API keys or credentials.

## IBM integration direction

- **Db2:** can replace or complement mock protected records. Database row/column access controls and auditing would add data-layer enforcement.
- **watsonx.ai:** an optional ambiguity advisor can provide an additional signal for unclear intent cases. Deterministic policy still controls high-impact actions.
- **LinuxONE:** a deployment target for the gateway and policy service. Secure Execution for Linux can isolate secure guest workloads, but does not replace application authorization or data access policy.
- **watsonx.data and DataStage:** optional extensions for governed data and data preparation; neither is required for the mock demo.

## Evaluation

`python scenarios/runner.py` runs synthetic examples against no-guard, baseline, and full-policy paths. The runner reports attack success, false-block rate, task completion retention, decision latency, and escalation rate. Review its scenario definitions before presenting numbers; results are only meaningful when they reflect actual side effects and repeated runs.

## Limitations

- This is a hackathon prototype, not a production security boundary.
- The environment contains synthetic mock data only.
- Provenance tracking is explicit and limited to tagged inputs.
- Risk scoring is heuristic and has not been calibrated.
- The local dashboard does not include enterprise authentication or role-based access control.
- IBM services are optional adapters and may need environment-specific configuration.

## Deployment profile (safe integration stage)

AgentGuard has an explicit production profile so a deployment does not silently behave like the local mock demo. For a local production-profile run, copy `.env.example` to `.env`, set `AGENTGUARD_MODE=production`, generate two different random secrets of at least 32 characters for `AGENTGUARD_API_TOKEN` and `AGENTGUARD_REVIEWER_TOKEN`, and set `AGENTGUARD_DB_PATH` to a persistent writable volume. The application fails at startup if these secrets are missing. Keep `.env` out of source control.

Build the container from the repository root with `docker build -f infra/Dockerfile -t agentguard:local .`. Run it with your platform's secret manager and persistent volume mounted at the configured database path. Put it behind TLS and an organization identity-aware reverse proxy; do not expose the raw service port publicly. The service token is for trusted agent/workload callers. The separate reviewer token protects approval reads. Production approval execution is intentionally disabled until a real tool executor and organization identity/role mapping are installed.

`AGENTGUARD_MODE=production` disables the dashboard, API documentation, demo scenarios, and demo reset endpoints. `POST /v1/actions/evaluate` performs an authenticated, audited preflight decision without side effects. `POST /v1/actions/evaluate-and-execute` fails closed because this repository currently has no live email, filesystem, payment, or cloud executor. This avoids accidentally sending email, deleting real files, or submitting real payments. Connect a specific provider through a least-privilege adapter before enabling real side effects. The current IBM Db2 and watsonx.ai classes are integration stubs; setting their environment flags does not create a live connection. `GET /health` reports `live_tool_executor: not_configured` for this reason.

For a genuine IBM-connected deployment, provision a Db2 service and a watsonx.ai project, keep credentials in IBM Cloud Secrets Manager or the deployment platform's secret manager, and implement/test the corresponding adapters before setting them active. Keep Db2 credentials read-only for policy context and audit access unless write access is explicitly needed. Use watsonx.ai only as an advisory signal: deterministic policy and human approval should remain authoritative for high-impact actions. LinuxONE can host the containerized gateway and its supporting services; it does not itself provide agent authorization, tool adapters, or identity management.
