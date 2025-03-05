# File: order_retrieval.py
import boto3
import json
import os
from flask import Flask, request, jsonify

# Initialize Flask and AWS clients
app = Flask(__name__)
sqs = boto3.client('sqs')
API_KEY = os.getenv("API_KEY")
SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL")

print(f"API_KEY configured: {API_KEY}")
print(f"SQS_QUEUE_URL configured: {SQS_QUEUE_URL}")

@app.route('/process', methods=['POST'])
def process_order():
    api_key = request.headers.get('x-api-key')
    print(f"Request received with API key: {api_key}")

    if api_key != API_KEY:
        print("Authentication failed")
        return jsonify({"error": "Unauthorized"}), 401

    try:
        print("Retrieving message from SQS...")
        response = sqs.receive_message(
            QueueUrl=SQS_QUEUE_URL,
            MaxNumberOfMessages=1,
            WaitTimeSeconds=5
        )

        if 'Messages' not in response:
            print("No messages in queue")
            return jsonify({"message": "No orders to process"}), 200

        message = response['Messages'][0]
        order = json.loads(message['Body'])
        print(f"Retrieved order: {json.dumps(order, indent=2)}")

        sqs.delete_message(
            QueueUrl=SQS_QUEUE_URL,
            ReceiptHandle=message['ReceiptHandle']
        )

        print(f"Order processed successfully: {json.dumps(order, indent=2)}")
        return jsonify({"order": order}), 200

    except Exception as e:
        print(f"Error processing order: {str(e)}")
        return jsonify({"error": str(e)}), 500

def lambda_handler(event, context):
    print(f"Lambda handler starting with event: {json.dumps(event, indent=2)}")

    try:
        with app.test_request_context(
            path=event.get('rawPath', '/process'),
            method='POST',
            headers=event.get('headers', {}),
            data=event.get('body', '')
        ):
            response = app.full_dispatch_request()
            print(f"Processing complete. Response: {response.get_data(as_text=True)}")

            return {
                'statusCode': response.status_code,
                'headers': {'Content-Type': 'application/json'},
                'body': response.get_data(as_text=True)
            }
    except Exception as e:
        error_msg = f"Error in handler: {str(e)}"
        print(error_msg)
        return {
            'statusCode': 500,
            'body': json.dumps({"error": error_msg})
        }
