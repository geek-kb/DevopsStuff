#!/bin/bash
region=$1
vpcId=$2
aws ec2 describe-subnets --region $region | jq --arg vpcid $vpcId -r '.Subnets[] | select(.VpcId==$vpcid) |.CidrBlock'
