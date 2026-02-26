def test_rate_limiting_login_endpoint(client):
    """
    Test rate limiting on the /login endpoint.
    Should allow 5 requests, block the 6th with 429.
    """
    # Toggle Limiter ON for this specific test
    from app.core.rate_limit import limiter

    limiter.enabled = True

    # Clear in-memory storage to prevent cross-test flakiness
    if hasattr(limiter, "_storage") and hasattr(limiter._storage, "storage"):
        limiter._storage.storage.clear()

    # Use a dummy login payload, we expect 401s or 200s for the first 5, but 429 for the 6th
    payload = {"username": "testuser", "password": "password"}

    headers = {"X-Forwarded-For": "192.168.99.99"}

    # Make 5 requests (should NOT be 429)
    for _ in range(5):
        response = client.post("/v1/login", json=payload, headers=headers)
        assert response.status_code != 429  # Usually 401 Unauthorized for bad creds

    # 6th request MUST be 429
    response_429 = client.post("/v1/login", json=payload, headers=headers)
    assert response_429.status_code == 429
    assert response_429.json()["detail"] == "Too many requests"

    # Teardown
    limiter.enabled = False
