import logging

from fastapi.testclient import TestClient

from app.main import app


def test_timing_middleware_logs_duration(caplog):
    """Verify that TimingMiddleware logs request_complete with duration_ms."""
    client = TestClient(app)

    with caplog.at_level(logging.INFO, logger="app.core.timing"):
        response = client.get("/v1/health")

    assert response.status_code == 200

    # Find the log record
    log_record = None
    for record in caplog.records:
        if record.message == "request_complete":
            log_record = record
            break

    assert log_record is not None, "Timing log not emitted"

    # Verify that the middleware injected the extra attributes
    assert hasattr(log_record, "method")
    assert log_record.method == "GET"

    assert hasattr(log_record, "path")
    assert log_record.path == "/v1/health"

    assert hasattr(log_record, "status_code")
    assert log_record.status_code == 200

    assert hasattr(log_record, "duration_ms")
    assert isinstance(log_record.duration_ms, float)
    assert log_record.duration_ms > 0
