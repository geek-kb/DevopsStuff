#!/usr/bin/env python3
# This script expects three arguments to be passed to it:
# timestamp, elastic group names, status text
# Script by Itai Ganot 
import boto3
from botocore.exceptions import ClientError
import datetime
import base64
import signalfx
import pytz
import argparse

signalfxSecretName = 'prod/signalfx/token'


def parseTime(timestamp):
    IST = pytz.timezone('Asia/Jerusalem')
    userPassedTS = datetime.datetime.strptime(timestamp, '%Y-%m-%d:%H:%M:%S')
    time_no_ts = datetime.datetime.timestamp(userPassedTS.astimezone(IST))
    timeStamp = int(time_no_ts) * 1000
    return timeStamp


def get_secret_from_aws_secrets_manager(secret_name):
    region_name = "us-east-1"

    # Create a Secrets Manager client
    session = boto3.session.Session() #Enable to use IAM role
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )
    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        if e.response['Error']['Code'] == 'DecryptionFailureException':
            # Secrets Manager can't decrypt the protected secret text using the provided KMS key.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'InternalServiceErrorException':
            # An error occurred on the server side.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'InvalidParameterException':
            # You provided an invalid value for a parameter.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'InvalidRequestException':
            # You provided a parameter value that is not valid for the current state of the resource.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
        elif e.response['Error']['Code'] == 'ResourceNotFoundException':
            # We can't find the resource that you asked for.
            # Deal with the exception here, and/or rethrow at your discretion.
            raise e
    else:
        # Decrypts secret using the associated KMS CMK.
        # Depending on whether the secret is a string or binary, one of these fields will be populated.
        if 'SecretString' in get_secret_value_response:
            secret = get_secret_value_response['SecretString']
            return secret
        else:
            decoded_binary_secret = base64.b64decode(
                get_secret_value_response['SecretBinary'])
            return decoded_binary_secret


SIGNALFX_TOKEN = get_secret_from_aws_secrets_manager(signalfxSecretName)

def userTimeToTimestamp(usersTime):
    usersTimeE = usersTime.split(':')[0] + ' ' + usersTime.split(':')[1]+':'+ usersTime.split(':')[2] + ':' + usersTime.split(':')[3]
    print('usersTimeE: {}'.format(usersTimeE))
    timeStamp = datetime.datetime.strptime(usersTimeE, '%Y-%m-%d %H:%M:%S')
    return timeStamp


def postRequestSignalFX(eventTime, elasticGroups, status):
    sfToken = str(SIGNALFX_TOKEN).split(":")[1][:-1].strip("\"")
    with signalfx.SignalFx().ingest(sfToken) as sfx:
        try:
            sfx.send_event(
                event_type='Deployment of:',
                dimensions={
                    'name': elasticGroups,
                    'status': status
                },
                timestamp=eventTime
            )
        except Exception as postE:
            print(postE)
        finally:
            sfx.stop

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Send deployment event to SignalFX')
    parser.add_argument('-e',
                        '--elasticgroups',
                        help='affected elasticgroups',
                        required=True)
    parser.add_argument('-s',
                        '--status',
                        help='status',
                        required=True)
    parser.add_argument('-t',
                        '--timestamp',
                        help='Timestamp',
                        required=True)
    args = parser.parse_args()
    timeStamp = parseTime(args.timestamp)
    postRequestSignalFX(timeStamp, args.elasticgroups, args.status)

