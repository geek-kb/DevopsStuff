#!/usr/bin/env python3
import json
import boto3
import base64
import datetime
from google.cloud import bigquery
from botocore.exceptions import ClientError
from os import environ
import requests
import tempfile
import signalfx
import atexit
import os

googleSecretName = os.environ['googleSecretName']
coralogixSecretName = os.environ['coralogixSecretName']
signalfxSecretName = os.environ['signalfxSecretName']
gcpTableName = os.environ['gcpTableName']
iconUrl = u'https://i.ibb.co/Q65WFNQ/cmh-1.png'
hoursDelta = os.environ['hoursDelta']

epoch = datetime.datetime.utcfromtimestamp(0)
todayDate = datetime.date.today()
timeNow = datetime.datetime.now()
timeDelta = timeNow + datetime.timedelta(hours=int(hoursDelta))
nowTimePlusHour = timeDelta.hour

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


GOOGLE_APPLICATION_CREDENTIALS = get_secret_from_aws_secrets_manager(googleSecretName)
SIGNALFX_TOKEN = get_secret_from_aws_secrets_manager(signalfxSecretName)
CORALOGIX_TOKEN = get_secret_from_aws_secrets_manager(coralogixSecretName)


def query_gcp(gcpTableName):
    client = bigquery.Client()
    tableName = 'maanalyticsplatform.CM_DWH.dim_liveops'
    query_job = client.query("SELECT * FROM {} WHERE starts_at_date = '{}'".format(tableName,str(todayDate)))
    defaultTextStart = 'LiveOps_event_start: '
    defaultTextEnd = 'LiveOps_event_end: '
    results = query_job.result()
    for row in results:
        eventName = str(row[1])
        eventStartTime = datetime.datetime.isoformat(row[2])
        eventEndTime = datetime.datetime.isoformat(row[4])
        eventStartHour = eventStartTime.split("T")[1][:2]
        eventStartTime_TimeStamp = int(datetime.datetime.timestamp(row[2]) * 1000)
        eventEndTime_TimeStamp = int(datetime.datetime.timestamp(row[4]) * 1000)
        #print('event name: {}, eventStartTime: {}, today date: {}, timeNow: {}, nowTimePlusHour = {}, eventStartHour: {}'.format(eventName, eventStartTime, todayDate, timeNow, nowTimePlusHour, eventStartHour))
        if eventStartHour[0] == '0':
            eventStartHour = eventStartHour[-1:]
        
        if nowTimePlusHour == eventStartHour:
            postRequestCoralogix(eventName, defaultTextStart, eventStartTime[:-6]+'.000Z')
            print('Event {} starts at {} has been notified to Coralogix'.format(eventName, eventStartTime))
            postRequestCoralogix(eventName, defaultTextEnd, eventEndTime[:-6]+'.000Z')
            print('Event {} ends at {} has been notified to Coralogix'.format(eventName, eventEndTime))
            postRequestSignalFX(eventStartTime_TimeStamp, eventName, 'start')
            print('Event {} starts at {} has been notified to SignalFX'.format(eventName, eventStartTime))
            postRequestSignalFX(eventEndTime_TimeStamp, eventName, 'end')
            print('Event {} ends at {} has been notified to SignalFX'.format(eventName, eventEndTime))


def postRequestCoralogix(eventName, eventText, timestamp):
    coralogixApiUrl = "https://api.coralogix.com/api/v1/addTag?key={}&application=COMPANYGAME&subsystem=gameserver&name=\"{}{}\"&timestamp={}&iconUrl={}".format(
        eval(str(CORALOGIX_TOKEN).split(':')[1][:-1]),
        eventText,
        eventName,
        timestamp,
        iconUrl)
    try:
        print('coralogix url: {}'.format(coralogixApiUrl))
        response = requests.get(coralogixApiUrl)
        print('response text: {}, response status: {}'.format(response.text, response.status_code))
    except Exception as e:
        print('Error updating Coralogix with event {}, http status returned: {}, exception: {}'.format(
            eventName,
            response.status_code,
            e))


def postRequestSignalFX(eventTime, eventName, eventStatus):
    sfToken = str(SIGNALFX_TOKEN).split(":")[1][:-1].strip("\"")
    with signalfx.SignalFx().ingest(sfToken) as sfx:
        try:
            sfx.send_event(
                event_type='LiveOps_event',
                dimensions={
                    'name': eventName,
                    'status': eventStatus
                },
                timestamp=eventTime
            )
        finally:
            atexit.register(sfx.stop)


def events_handler(event, context):
    with tempfile.NamedTemporaryFile('w',encoding='utf-8',suffix='.json',delete=False) as keyfile:
        with open(keyfile.name, 'w') as fd:
            fd.write(GOOGLE_APPLICATION_CREDENTIALS)
            environ["GOOGLE_APPLICATION_CREDENTIALS"] = fd.name
            fd.close()

    query_gcp(gcpTableName)

    os.system('rm -f {}'.format(fd.name))
