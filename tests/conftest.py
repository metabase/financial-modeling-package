from unittest.mock import Mock
import pytest


@pytest.fixture(autouse=True)
def mock_request(monkeypatch):
    req = Mock()
    monkeypatch.setattr('requests.api.request', req)
    return req
