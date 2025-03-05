import boto3
import json
import logging
import os
import re
from botocore.exceptions import ClientError
from boto3.dynamodb.conditions import Key
from decimal import Decimal

# Configure logging
default_log_args = {
    "level": logging.DEBUG if os.environ.get("DEBUG", False) else logging.INFO,
    "format": "%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    "datefmt": "%d-%b-%y %H:%M",
    "force": True,
}
logging.basicConfig(**default_log_args)
logger = logging.getLogger(__name__)

# Initialize AWS services
s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
sqs = boto3.client('sqs')

# Environment variables
DYNAMODB_TABLE_NAME = os.getenv("DYNAMODB_TABLE_NAME")
SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL")


def lambda_handler(event, context):
    logger.info("Lambda function has been triggered.")
    try:
        logger.info("Received event: %s", json.dumps(event))

        # Extract S3 bucket and object key from the event
        bucket_name = event['Records'][0]['s3']['bucket']['name']
        object_key = event['Records'][0]['s3']['object']['key']

        logger.info(f"Extracted bucket: {bucket_name}, object key: {object_key}")

        # Retrieve and parse the uploaded JSON file
        file_content = get_file_from_s3(bucket_name, object_key)
        logger.debug(f"File content: {file_content}")

        order_data = json.loads(file_content)
        logger.info(f"Parsed order data: {order_data}")

        # Validate the order
        if validate_order(order_data):
            send_to_sqs(order_data)
            logger.info(f"Order {order_data['orderId']} is valid and sent to SQS.")
            return {"statusCode": 200, "body": "Order processed successfully"}
        else:
            logger.error(f"Order {order_data['orderId']} is invalid.")
            return {"statusCode": 400, "body": "Invalid order"}

    except ClientError as e:
        logger.error(f"AWS ClientError occurred: {e}")
        return {"statusCode": 500, "body": f"Internal server error: {str(e)}"}

    except Exception as e:
        logger.error(f"Unexpected error occurred: {e}")
        return {"statusCode": 500, "body": f"Internal server error: {str(e)}"}


def get_file_from_s3(bucket_name, object_key):
    logger.info(f"Attempting to retrieve file: {object_key} from bucket: {bucket_name}")
    try:
        response = s3.get_object(Bucket=bucket_name, Key=object_key)
        logger.debug(f"S3 response metadata: {response['ResponseMetadata']}")

        file_content = response['Body'].read().decode('utf-8')
        logger.info(f"Successfully retrieved file {object_key} from bucket {bucket_name}.")
        return file_content
    except Exception as e:
        logger.error(f"Failed to retrieve file {object_key} from bucket {bucket_name}: {e}")
        raise

def validate_order(order_data):
    """
    Validate the order by querying DynamoDB and checking for matches with productId and productName.
    If any match is found, return True.
    """
    logger.info(f"Validating order: {order_data}")
    table = dynamodb.Table(DYNAMODB_TABLE_NAME)

    try:
        for item in order_data["items"]:
            partition_key = f"{item['productId']}#{order_data['customerEmail']}"
            sort_key = item["productName"]

            # Query DynamoDB for matching items
            response = table.query(
                KeyConditionExpression=Key("partitionKey").eq(partition_key) &
                                       Key("sortKey").eq(sort_key)
            )
            if response.get("Count", 0) > 0:
                logger.info(f"Item with productId {item['productId']} and productName {item['productName']} exists.")
                return True  # Valid if any item matches

        logger.warning(f"No matching items found for order {order_data['orderId']}.")
        return False

    except Exception as e:
        logger.error(f"Failed to validate order: {e}")
        return False

def send_to_sqs(order_data):
    """
    Send the valid order details to the SQS queue for further processing.
    """
    logger.info(f"Sending order to SQS: {order_data}")
    try:
        response = sqs.send_message(QueueUrl=SQS_QUEUE_URL, MessageBody=json.dumps(order_data))
        logger.debug(f"SQS response: {response}")
        logger.info(f"Order {order_data['orderId']} successfully sent to SQS queue.")
    except Exception as e:
        logger.error(f"Failed to send order to SQS: {e}")
        raise
