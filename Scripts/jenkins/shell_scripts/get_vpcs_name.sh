#!/bin/bash
region=$1
aws ec2 describe-vpcs --region ${region} | jq -r '.Vpcs[].Tags[]? | select(.Key=="Name") | .Value'
