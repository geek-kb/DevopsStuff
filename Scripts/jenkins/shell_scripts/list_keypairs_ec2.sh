#!/bin/bash
region=$1
aws ec2 describe-key-pairs --region ${region} | jq -r '.KeyPairs[] | .KeyName' 
