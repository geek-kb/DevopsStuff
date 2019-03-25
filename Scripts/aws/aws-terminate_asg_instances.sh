#!/bin/bash

# populte asgname with the value of the first argument.
asgname=$1

# function to display usage, exits program after displaying it.
function usage(){
  echo "Usage:"
  echo "$basename$0 Autoscalinggroup_name"
  exit 1
}

# function that checks the exit status of the previous command
function exitCode(){
  if [[ $? -ne 0 ]]; then
    echo "Error, command failed!"
    exit 1
  fi
}

# check if aws command exists in the OS.
which aws &>/dev/null
exitCode
echo "aws cli found!"
# check if an aws access key is configured.
aws configure get aws_access_key_id &>/dev/null
exitCode
echo "aws access key id configured correctly!"

# if auto scaling group name is not supplied, display usage and exit
if [ -z $asgname ]; then
  usage
fi

# populates variable instance_ids_to_terminate with list of instance ids
instance_ids_to_terminate=$(aws autoscaling describe-auto-scaling-instances | jq --arg asgname $asgname -r '.AutoScalingInstances[] | select(.AutoScalingGroupName==$asgname) | .InstanceId' | xargs)
echo "The following instances are going to be removed:"
echo $instance_ids_to_terminate

# Asks the user if he approves the changes
read -r -p "Are you sure? [y/n]" answer
if [[ $answer = [Yy] ]]; then
  # run command to terminate found instance ids
  aws ec2 terminate-instances --instance-ids $instance_ids_to_terminate
elif [[ $answer = [Nn ]]; then
  echo "User chose not to terminate!"
  exit 0
fi
