#!/bin/bash
ubuntuAmiId=ami-04b9e92b5572fa0d1
if [[ -z $name ]]; then
 echo "Name of instance not chosen!"
 exit 1
fi
cd scripts
sid=$(./get_subnetid_by_cidr.sh $Region $vpcCidr)
echo "Creating a new instance with name: $name in VPC $vpcName in subnet $sid with keypair $keyPair"
aws ec2  run-instances --image-id $ubuntuAmiId --instance-type "t2.micro" --key-name $keyPair --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$name}]" --subnet-id $sid

instanceId=$(aws ec2 describe-instances | jq -r --arg instancename $name '.Reservations[].Instances[] | select(.Tags[]?.Value==$instancename) |.InstanceId')

counter=1

while [[ $counter -lt 240 ]]; do
  status=$(aws ec2 describe-instance-status --instance-ids $instanceId  | jq -r '.InstanceStatuses[].SystemStatus.Status')
  if [[ $status != "ok" ]]; then
      echo "Waiting for instance to start"
      sleep 5
      ((counter++))
    else
      echo "Instance is up with instance id $instanceId"
      exit 0
    fi
done
exit 1
