# AgentGuard deployment and IBM connection guide

## What the current build does

The local `demo` profile has a dashboard, deterministic policy rules, synthetic inbox/files/payments, a human-review queue, and an SQLite audit log. It is for demonstrations. It does not connect to real mailboxes, operating-system files, bank/payment rails, or IBM services.

The `production` profile is deliberately fail-closed. It requires separate service and reviewer bearer tokens, hides the demo UI and API docs, accepts authenticated policy preflight requests, and refuses to execute tool actions or approve them until real least-privilege tool adapters exist. This is a safe deployment foundation, not a claim that live actions are already integrated.

## Local production-profile setup

1. Copy `.env.example` to `.env` and set `AGENTGUARD_MODE=production`.
2. Generate two different long random values (32+ characters) and put them in `AGENTGUARD_API_TOKEN` and `AGENTGUARD_REVIEWER_TOKEN`. For example, PowerShell can generate one with `[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))`.
3. Set `AGENTGUARD_DB_PATH` to a persistent path writable by the service account. Use a new database for production; do not reuse the demo database.
4. Start the API with the included Dockerfile or run `uvicorn agentguard.api:app --host 127.0.0.1 --port 8001` in the Python environment.
5. Put a TLS reverse proxy and organization SSO/identity provider in front of the API. Keep the service token in the agent's secret manager and reviewer credentials in a separate reviewer system. The sample bearer tokens are shared secrets, not a substitute for per-user identity, role-based access, or rotation.
6. Send `POST /v1/actions/evaluate` with `Authorization: Bearer <AGENTGUARD_API_TOKEN>` for a no-side-effect policy decision. A reviewer-token-protected approval list is available, but production approval execution is intentionally unavailable until execution adapters and identity mapping are built.

## Build the container

From the repository root:

```powershell
docker build -f infra/Dockerfile -t agentguard:local .
```

At deployment time, provide settings through the platform's secret manager rather than baking `.env` into the image. Mount persistent storage for the audit database. Restrict inbound traffic to the reverse proxy, use TLS, run as the non-root container user, and send audit events to a managed append-only logging destination for operational retention. For multiple replicas or high availability, replace SQLite with a managed transactional database and use a shared approval/idempotency store.

## IBM services and their role

### IBM watsonx.ai

Provision an IBM Cloud account, a watsonx.ai project, an API key, a project ID, and the correct regional API URL. Store those values in the deployment secret manager as `IBM_WATSONX_API_KEY`, `IBM_WATSONX_PROJECT_ID`, and `IBM_WATSONX_URL`. The repository currently contains a watsonx advisor stub: it does not make an API call even when these variables are filled. Implement the SDK call in `agentguard/integrations/ibm_adapters.py`, set strict timeouts, log only non-sensitive decision metadata, and treat model output as advisory. A deterministic policy must retain final authority over sensitive actions.

### IBM Db2

Provision Db2 and create a least-privilege service identity. Store the connection configuration in a secret manager (for example, a DSN/connection string and certificate material), not in source code. Add the IBM Db2 Python driver to the deployment image and implement connection, parameterized queries, timeouts, TLS verification, and health checks in `Db2Adapter`. Use read-only access for protected-record lookups where possible. The current `Db2Adapter` is a stub; `IBM_DB2_ENABLED=true` does not establish a connection by itself.

### LinuxONE

LinuxONE is a hosting and isolation option for the AgentGuard service and its supporting workloads. Build and deploy the container using your IBM environment's approved platform, attach persistent managed storage and secrets, and expose the API only through the authenticated TLS gateway. Secure Execution can protect supported guest workloads and data in use; it does not replace AgentGuard's policy, API authentication, approval identity, or provider-specific authorization.

## Before permitting live tool execution

Implement each real executor behind an explicit interface and connect only the providers required for the demo. Start with a sandbox/test tenant, read-only scopes, and a dry-run mode. Bind caller identity and user intent from an authenticated server-side context; do not trust `requested_by_user` or provenance labels supplied by an arbitrary agent. Bind approvals to the exact action payload, reviewer identity, policy version, and expiry, and enforce one-time approval atomically. Add rate limits, timeouts, retry/idempotency rules, secrets redaction, monitoring, incident rollback procedures, and security review. Only then enable specific live actions using provider-level least-privilege credentials.

## Current status at a glance

| Capability | Current status |
|---|---|
| Policy scoring and preflight endpoint | Implemented; heuristic rules, not a trained model |
| Dashboard and demo scenarios | Implemented for synthetic mock data |
| Production API token checks | Implemented with shared bearer tokens |
| Reviewer token check | Implemented for approval listing |
| Production side-effect execution | Disabled until real adapters are implemented |
| Db2 | Stub only; no connection |
| watsonx.ai | Stub only; no model call |
| LinuxONE | Deployment target guidance; no host connected |
| SSO, individual RBAC, managed DB, distributed approvals | Must be supplied/integrated by deployment |
