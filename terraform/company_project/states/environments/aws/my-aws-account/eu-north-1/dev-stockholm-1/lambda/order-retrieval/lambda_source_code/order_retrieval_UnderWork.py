import boto3
import json
import os
import logging
from botocore.exceptions import ClientError
from boto3.dynamodb.conditions import Key
from flask import Flask, request, jsonify

# Configure logging
default_log_args = {
    "level": logging.DEBUG if os.environ.get("DEBUG", False) else logging.INFO,
    "format": "%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    "datefmt": "%d-%b-%y %H:%M",
    "force": True,
}
logging.basicConfig(**default_log_args)
logger = logging.getLogger(__name__)

# Initialize Flask and AWS clients
app = Flask(__name__)
sqs = boto3.client('sqs')
ssm = boto3.client('ssm')

API_KEY_PARAMETER_NAME = os.getenv("API_KEY_PARAMETER_NAME")
SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL")

logger.info(f"API_KEY_PARAMETER_NAME configured: {API_KEY_PARAMETER_NAME}")
logger.info(f"SQS_QUEUE_URL configured: {SQS_QUEUE_URL}")

@app.route('/process', methods=['POST'])
def process_order():
    API_KEY = ssm.get_parameter(Name=API_KEY_PARAMETER_NAME, WithDecryption=True)
    api_key = request.headers.get('x-api-key')
    logger.debug(f"Request received with API key: {api_key}")

    if api_key != API_KEY:
        logger.warning("Authentication failed")
        return jsonify({"error": "Unauthorized"}), 401

    try:
        logger.info("Retrieving message from SQS...")
        response = sqs.receive_message(
            QueueUrl=SQS_QUEUE_URL,
            MaxNumberOfMessages=1,
            WaitTimeSeconds=5
        )

        if 'Messages' not in response:
            logger.info("No messages in queue")
            return jsonify({"message": "No orders to process"}), 200

        message = response['Messages'][0]
        order = json.loads(message['Body'])
        logger.debug(f"Retrieved order: {json.dumps(order, indent=2)}")

        sqs.delete_message(
            QueueUrl=SQS_QUEUE_URL,
            ReceiptHandle=message['ReceiptHandle']
        )

        logger.info(f"Order processed successfully: {json.dumps(order, indent=2)}")
        return jsonify({"order": order}), 200

    except ClientError as e:
        logger.error(f"AWS Service error processing order: {str(e)}")
        return jsonify({"error": str(e)}), 500
    except Exception as e:
        logger.error(f"Error processing order: {str(e)}", exc_info=True)
        return jsonify({"error": str(e)}), 500

def lambda_handler(event, context):
    logger.info(f"Lambda handler starting with event: {json.dumps(event, indent=2)}")

    try:
        with app.test_request_context(
            path=event.get('rawPath', '/process'),
            method='POST',
            headers=event.get('headers', {}),
            data=event.get('body', '')
        ):
            response = app.full_dispatch_request()
            logger.debug(f"Processing complete. Response: {response.get_data(as_text=True)}")

            return {
                'statusCode': response.status_code,
                'headers': {'Content-Type': 'application/json'},
                'body': response.get_data(as_text=True)
            }
    except Exception as e:
        error_msg = f"Error in handler: {str(e)}"
        logger.error(error_msg, exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({"error": error_msg})
        }
