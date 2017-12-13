#!/usr/bin/python
import boto3
import re, sys

if len(sys.argv) < 2:
    print('Please supply Hosted Zone Id')
    sys.exit()

region = 'eu-west-1'

hostedzoneid = sys.argv[1]  

r53client = boto3.client('route53')

response = r53client.list_resource_record_sets(
        HostedZoneId=hostedzoneid,
        StartRecordName='dev',
        StartRecordType='A'
        )

for resource in response['ResourceRecordSets']:
  records = resource['ResourceRecords'][0]
  if 'Name' in resource:
    name = re.findall('api|batch|analytics', resource['Name'])
    if name:
      print records['Value']
      #print records['Value'], name[0]
