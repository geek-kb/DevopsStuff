#!/bin/bash
aws ec2 describe-vpcs --region us-east-1 | jq -r '.Vpcs[].Tags[]? | select(.Key=="Name") | .Value'
