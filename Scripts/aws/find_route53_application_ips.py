#!/usr/bin/python
# This script receives a Hosted Zone Id as parameter and returns the IPs of the servers that match the regex in variable "reg".
# Itai Ganot 2017
import boto3
import re, sys

reg = 'api|analytics|batch'

if len(sys.argv) < 2:
    print('Please supply Hosted Zone Id')
    sys.exit()

region = 'eu-west-1'

hostedzoneid = sys.argv[1]  

r53client = boto3.client('route53')

response = r53client.list_resource_record_sets(
        HostedZoneId=hostedzoneid,
        )

for resource in response['ResourceRecordSets']:
  records = resource['ResourceRecords'][0]
  if 'Name' in resource:
    name = re.findall(reg, resource['Name'])
    if name:
      print records['Value']
