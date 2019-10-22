#!/bin/bash
region=$1
cidr=$2
aws ec2 describe-subnets | jq -r --arg cr $cidr '.Subnets[] | select(.CidrBlock | contains($cr)) | .SubnetId'
