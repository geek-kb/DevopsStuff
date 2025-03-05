import json
import os
import pytest
from unittest.mock import patch, MagicMock
from order_retrieval import app, lambda_handler

@pytest.fixture(autouse=True)
def setup_environment(monkeypatch):
    """Configure environment before each test"""
    api_key = "b6f5a2d96a8e4f98b1c3d7a54e9f8b2c"
    queue_url = "https://sqs.eu-north-1.amazonaws.com/912466608750/order-processor"

    # Set environment variables
    monkeypatch.setenv("API_KEY", api_key)
    monkeypatch.setenv("SQS_QUEUE_URL", queue_url)

    # Force reload environment variables in app
    import order_retrieval
    order_retrieval.API_KEY = api_key
    order_retrieval.SQS_QUEUE_URL = queue_url

    print("\nTest Environment Setup:")
    print(f"✓ API Key: {api_key}")
    print(f"✓ Queue URL: {queue_url}")

    return {"api_key": api_key, "queue_url": queue_url}

class TestOrderRetrieval:
    """Test suite for Order Retrieval Lambda function"""

    def test_successful_order_retrieval(self, setup_environment, capsys):
        """Test successful order retrieval with valid API key"""
        print("\nTesting successful order retrieval:")

        test_order = {
            'orderId': '123',
            'items': [{'id': '1', 'quantity': 2}]
        }
        print(f"Test order: {json.dumps(test_order, indent=2)}")

        with patch('order_retrieval.sqs') as mock_sqs:
            mock_sqs.receive_message.return_value = {
                'Messages': [{
                    'Body': json.dumps(test_order),
                    'ReceiptHandle': 'receipt123'
                }]
            }
            print("✓ Mocked SQS")

            event = {
                'rawPath': '/process',
                'headers': {'x-api-key': setup_environment['api_key']}
            }
            print(f"✓ Event created")

            response = lambda_handler(event, None)
            print(f"Response: {json.dumps(response, indent=2)}")

            assert response['statusCode'] == 200
            response_body = json.loads(response['body'])
            assert 'order' in response_body
            assert response_body['order'] == test_order
            print("✓ Assertions passed")

    def test_empty_queue(self, mock_env, capsys):
        """
        Test empty queue handling.
        Verifies:
        1. Valid API key authentication
        2. Empty queue response
        """
        print("\nTesting empty queue handling:")
        with patch('order_retrieval.sqs') as mock_sqs:
            mock_sqs.receive_message.return_value = {}
            print("✓ Mocked empty SQS queue")

            event = {'rawPath': '/process', 'headers': {'x-api-key': mock_env}}
            response = lambda_handler(event, None)
            print(f"Response received: {json.dumps(json.loads(response['body']), indent=2)}")

            assert response['statusCode'] == 200, "Should return 200 OK"
            assert json.loads(response['body'])['message'] == 'No orders to process'
            print("✓ All assertions passed")

    def test_invalid_api_key(self, mock_env, capsys):
        """
        Test invalid API key rejection.
        Verifies:
        1. Invalid API key detection
        2. 401 response
        3. Error message format
        """
        print("\nTesting invalid API key:")
        event = {'rawPath': '/process', 'headers': {'x-api-key': 'invalid_key'}}
        print("✓ Created event with invalid API key")

        response = lambda_handler(event, None)
        print(f"Response received: {json.dumps(json.loads(response['body']), indent=2)}")

        assert response['statusCode'] == 401, "Should return 401 Unauthorized"
        assert 'error' in json.loads(response['body']), "Should include error message"
        print("✓ All assertions passed")
