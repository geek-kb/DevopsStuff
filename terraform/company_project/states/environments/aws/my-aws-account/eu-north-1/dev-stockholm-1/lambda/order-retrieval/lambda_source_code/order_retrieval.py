import boto3
import json
import os
import logging
from typing import Dict, Any
from botocore.exceptions import ClientError
from flask import Flask, request, jsonify, Response

# Configure logging
default_log_args = {
    "level": logging.DEBUG if os.environ.get("DEBUG", False) else logging.INFO,
    "format": "%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    "datefmt": "%d-%b-%y %H:%M",
    "force": True,
}
logging.basicConfig(**default_log_args)
logger = logging.getLogger(__name__)

# Constants
API_KEY_PARAMETER_NAME = os.getenv("API_KEY_PARAMETER_NAME")
SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL")

# Initialize Flask and AWS clients
app = Flask(__name__)
sqs = boto3.client('sqs')
ssm = boto3.client('ssm')

@app.route('/process', methods=['POST'])
def process_order() -> tuple[Response, int]:
    try:
        # Get API key from SSM
        api_key_param = ssm.get_parameter(
            Name=API_KEY_PARAMETER_NAME,
            WithDecryption=True
        )
        stored_api_key = api_key_param['Parameter']['Value'].strip()
        request_api_key = request.headers.get('x-api-key', '').strip()

        # Debug logging with masked keys
        logger.debug(f"API Key lengths - Stored: {len(stored_api_key)}, Request: {len(request_api_key)}")
        logger.debug(f"API Keys match: {stored_api_key == request_api_key}")

        if not request_api_key or request_api_key != stored_api_key:
            logger.warning(f"Authentication failed - Invalid API key or missing header")
            return jsonify({"error": "Unauthorized"}), 401

        # Process SQS message

        # Process SQS message
        logger.info("Retrieving message from SQS...")
        response = sqs.receive_message(
            QueueUrl=SQS_QUEUE_URL,
            MaxNumberOfMessages=1,
            WaitTimeSeconds=5
        )

        if 'Messages' not in response:
            return jsonify({"message": "No orders to process"}), 200

        message = response['Messages'][0]
        order = json.loads(message['Body'])

        # Delete message after processing
        sqs.delete_message(
            QueueUrl=SQS_QUEUE_URL,
            ReceiptHandle=message['ReceiptHandle']
        )

        logger.info(f"Order {order.get('orderId', 'unknown')} processed successfully")
        return jsonify({"order": order}), 200

    except ClientError as e:
        error_msg = f"AWS Service error: {e.response['Error']['Message']}"
        logger.error(error_msg)
        return jsonify({"error": error_msg}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    logger.info("Lambda handler starting")
    logger.debug(f"Event: {json.dumps(event, indent=2)}")

    try:
        with app.test_request_context(
            path=event.get('rawPath', '/process'),
            method='POST',
            headers=event.get('headers', {}),
            data=event.get('body', '')
        ):
            response = app.full_dispatch_request()
            return {
                'statusCode': response.status_code,
                'headers': {'Content-Type': 'application/json'},
                'body': response.get_data(as_text=True)
            }
    except Exception as e:
        error_msg = f"Lambda handler error: {str(e)}"
        logger.error(error_msg, exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({"error": error_msg})
        }
