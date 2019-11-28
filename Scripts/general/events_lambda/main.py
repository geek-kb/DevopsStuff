#!/usr/bin/env python3
# This python script reads from Google BigQuery table
# (maanalyticsplatform.CM_DWH.dim_liveops) data about upcoming events.
# It then parses he events and checks the start time of each event, if the
# event is about to start in the upcoming 1 hour (can be changed by supplying
# a different value to variable "hoursDelta") then a relevant status event is
# being sent to both Coralogix and SignalFX.
# In order for this script to work properly as an AWS Lambda, it is required to
# zip the whole dir containing all the reuiqrements and uploading the zip file
# to AWS.

import boto3
import base64
import datetime
from datetime import timezone, timedelta
import pytz
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

IST = pytz.timezone('Asia/Jerusalem')
todayDate = datetime.date.today()
utc_dt = datetime.datetime.now(timezone.utc)
isrTime = utc_dt.astimezone(IST)
timeDeltaPlus = isrTime + timedelta(hours=int(hoursDelta))
timeDeltaMin = isrTime - timedelta(hours=int(hoursDelta))
nowTimePlusHour = timeDeltaPlus.hour
nowTimeMinHour = timeDeltaMin.hour
israelTimeHour = str(isrTime).split(' ')[1].split(':')[0]
tomorrowDate = todayDate + timedelta(days=int(1))
#print('Israel Time: {}, timeDelta: {}, nowTimePlusHour:{}, tomorrowDate: {}'.format(isrTime,timeDelta,nowTimePlusHour,tomorrowDate))

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


def query_gcp(tableName,date):
    client = bigquery.Client()
    query_job = client.query("SELECT * FROM {} WHERE starts_at_date = '{}'".format(tableName,str(date)))
    results = query_job.result()
    return results


def postAll(eventName, eventStartTime, eventEndTime, eventStartTime_TimeStamp,eventEndTime_TimeStamp):
    coraEventStartText = 'LiveOps_event_start: '
    coraEventEndText = 'LiveOps_event_end: '
    postRequestCoralogix(eventName, coraEventStartText, eventStartTime[:-6]+'.000Z')
    print('Event {} starts at {} has been notified to Coralogix'.format(eventName, eventStartTime))
    postRequestCoralogix(eventName, coraEventEndText, eventEndTime[:-6]+'.000Z')
    print('Event {} ends at {} has been notified to Coralogix'.format(eventName, eventEndTime))
    postRequestSignalFX(eventStartTime_TimeStamp, eventName, 'start')
    print('Event {} starts at {} has been notified to SignalFX'.format(eventName, eventStartTime))
    postRequestSignalFX(eventEndTime_TimeStamp, eventName, 'end')
    print('Event {} ends at {} has been notified to SignalFX'.format(eventName, eventEndTime))


def parseResults(results):
    for row in results:
        eventName = str(row[1])
        eventStartTime = datetime.datetime.isoformat(row[2])
        eventEndTime = datetime.datetime.isoformat(row[4])
        eventStartHour = eventStartTime.split("T")[1].split(':')[0][:2]
        eventStartTime_TimeStamp = int(datetime.datetime.timestamp(row[2]) * 1000)
        eventEndTime_TimeStamp = int(datetime.datetime.timestamp(row[4]) * 1000)
        if eventStartHour == '00':
            if israelTimeHour == '23':
                print('israel time hour: {}, event start hour: {}'.format(israelTimeHour,eventStartHour))
                postAll(eventName, eventStartTime, eventEndTime, eventStartTime_TimeStamp,eventEndTime_TimeStamp)
                print('Event {} ends at {} has been notified to SignalFX'.format(eventName, eventEndTime))
        elif eventStartHour[0] == '0':
            eventStartHour = eventStartHour[-1:]
            if int(nowTimePlusHour) == int(eventStartHour) or int(nowTimeMinHour) == int(eventStartHour):
                print('now time plus hour: {}, event start hour: {}'.format(nowTimePlusHour,eventStartHour))
                postAll(eventName, eventStartTime, eventEndTime, eventStartTime_TimeStamp,eventEndTime_TimeStamp)
                print('Event {} ends at {} has been notified to SignalFX'.format(eventName, eventEndTime))
        print('event name: {}, eventStartTime: {}, today date: {}, timeNow(Israel time): {}, nowTimePlusHour = {}, eventStartHour: {}'.format(eventName, eventStartTime, todayDate, str(isrTime).split('.')[0], nowTimePlusHour, eventStartHour))


def postRequestCoralogix(eventName, eventText, timestamp):
    coralogixApiUrl = "https://api.coralogix.com/api/v1/addTag?key={}&application=coinmaster&subsystem=gameserver&name=\"{}{}\"&timestamp={}&iconUrl={}".format(
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

    try:
        todayQueryResults = query_gcp(gcpTableName,todayDate)
        parseResults(todayQueryResults)
        tomorrowQueryResults = query_gcp(gcpTableName,tomorrowDate)
        parseResults(tomorrowQueryResults)
    except Exception as e:
        print('Error: {}'.format(e))
    finally:
        os.system('rm -f {}'.format(fd.name))
