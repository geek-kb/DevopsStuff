#!/bin/bash
region=$1
vpcname=$2
aws ec2 describe-vpcs --region $region | jq -r ".Vpcs[] | select( .Tags[].Value| contains(\"$vpcname\")) | .VpcId"
