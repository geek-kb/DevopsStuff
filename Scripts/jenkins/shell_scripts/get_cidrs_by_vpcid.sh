#!/bin/bash
region=$1
vpcname=$2
vpcid=$(aws ec2 describe-vpcs --region $region | jq -r --arg vpcName $vpcname '.Vpcs[] | select( .Tags[]?.Value| contains($vpcName)) | .VpcId')
aws ec2 describe-subnets | jq -r --arg vi $vpcid '.Subnets[] | select(.VpcId | contains($vi))| .CidrBlock'
