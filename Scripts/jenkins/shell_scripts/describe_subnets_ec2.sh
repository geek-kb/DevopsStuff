#!/bin/bash
#region=$1
#vpcid=$2
#aws ec2 describe-subnets --region $region | jq -r ".Subnets[] | select( .VpcId| contains(\"$vpcid\")) | .SubnetId"
region=$1
vpcname=$2
vpcid=$(aws ec2 describe-vpcs --region $region | jq -r ".Vpcs[] | select( .Tags[].Value| contains(\"$vpcname\")) | .VpcId")
aws ec2 describe-subnets --region $region | jq -r ".Subnets[] | select( .VpcId| contains(\"$vpcid\")) | .SubnetId"

