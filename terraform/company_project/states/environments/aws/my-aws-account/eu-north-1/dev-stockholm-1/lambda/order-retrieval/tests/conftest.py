import pytest
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '../lambda_source_code'))

@pytest.fixture(autouse=True)
def mock_env(monkeypatch):
    """Reset environment before each test"""
    api_key = "b6f5a2d96a8e4f98b1c3d7a54e9f8b2c"
    monkeypatch.setenv("API_KEY", api_key)
    monkeypatch.setenv("SQS_QUEUE_URL", "https://sqs.eu-north-1.amazonaws.com/912466608750/order-processor")

    # Force reload of environment variables
    import order_retrieval
    order_retrieval.API_KEY = api_key
    return api_key
