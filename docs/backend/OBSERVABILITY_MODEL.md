# Observability and Audit Model

## Correlation ID

Correlation ID behavior is implemented in:

- `backend/app/core/correlation.py`

Header contract:

- Request/response header: `X-Correlation-ID`

Middleware behavior:

- If the request includes `X-Correlation-ID`, it is reused.
- If missing, a UUID4 value is generated.
- Value is attached to `request.state.correlation_id`.
- Value is stored in a context variable for logging access.
- Response always includes `X-Correlation-ID`.

## Structured Logging

Structured logging utilities are implemented in:

- `backend/app/core/structured_logging.py`

`log_event(...)` emits JSON payloads through Python logging with fields:

- `timestamp`
- `correlation_id`
- `rule_id`
- `event`
- `metadata`

Formatter support (`JsonLogFormatter`) also includes level-aware event output.

## Audit Events

Current audited governance events emitted through `log_event(...)`:

- `drift_resolved` (`backend/app/services/reconciliation.py`)
- `dispatch_created` (`backend/app/services/dispatch_entry.py`)
- `forecast_refreshed` (`backend/app/services/forecasting.py`)
- `domain_event_emitted` (`backend/app/services/event_relay.py`)

## Exception Logging

`AppException` handling logs structured error events using:

- event: `app_exception`
- level: `ERROR`
- metadata: exception metadata payload

Implementation location:

- `backend/app/core/exceptions.py`

## Prohibitions

- No `print(...)` statements in `backend/app`.
- No unstructured ad hoc logging for governance/audit events.
