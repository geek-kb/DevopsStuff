#!/bin/bash
# This is a code that runs when Jenkins finishes building an AWS CloudFormation stack
if [[ $stackcreated = true ]]; then
  defaultVpcId="vpc-20e2094b"
  stackVpcId=$(aws cloudformation describe-stacks --stack-name  Angelsense-${Environment}-${BUILD_NUMBER} | grep -A1 VPC | grep OutputValue | awk '{print $2}' | tr -d "\"")
  
  if [[ $(aws ec2 describe-vpc-peering-connections --filters Name=status-code,Values=pending-acceptance | grep -B3 VpcPeeringConnectionId | grep VpcId | awk '{print $2}' | tr -d '\"|,') = $defaultVpcId ]]; then
      pcxid=$(aws ec2 describe-vpc-peering-connections --filters Name=status-code,Values=pending-acceptance | grep -B3 VpcPeeringConnectionId | tail -1 | awk '{print $2}' | tr -d '\"|,')
  else
      echo "Unable to find vpc peering connection request!"
      exit 0
  fi
  aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $pcxid
  
  if [[ $? -eq "0" ]]; then
      echo "VPC Peering request accepted successfully!"
  fi
fi

