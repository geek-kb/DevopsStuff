#!/bin/bash
# This tool handles AWS security groups.
# It accepts the following arguments:
# credentials_profile, region and security_group_id
# It then checks if the security group is attached to any instance, if it does,
# It displays the list of instance id's and exits.
# If the security group is not attached to any instances, it checks if the SG
# is a vpc-default sg. If it is, then it prints out a message. if it's not, it
# asks the user if they want to delete the security group.
# If the user choooses to delete, the script first checks if the SG is
# referenced by any other security group or ENI.
# If it's referenced, then it displays the referencing SG's or the ENI's it's
# Attached to. Else, if it's not attached to any ENI and not referenced, it
# gets deleted.
# Script by Itai Ganot lel@lel.bz

# Color functions
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
BOLD=$(tput bold)
UNDERLINE=$(tput smul)
NOCOLOR=$(tput sgr0)

function colyellow {
	echo -e -n "${YELLOW}$* ${NOCOLOR}\n"
}

function colgreen {
	echo -e -n "${GREEN}$* ${NOCOLOR}\n"
}

function colred {
	echo -e -n "${RED}$* ${NOCOLOR}\n"
}

function colblue {
	echo -e -n "${BLUE}$* ${NOCOLOR}\n"
}

function bold {
	echo -e -n "${BOLD}$* ${NOCOLOR}\n"
}

function underline {
	echo -e -n "${UNDERLINE}$* ${NOCOLOR}\n"
}

# Output settings
export AWS_PAGER=""
#export AWS_DEFAULT_OUTPUT="table"
#unset AWS_PAGER
unset AWS_DEFAULT_OUTPUT

# Usage
function usage(){
  echo ${basename}${0} -p AWS_CREDENTIALS_PROFILE -r AWS_REGION -g AWS_EC2_GROUP_ID
}

# AWS functions
function display_referring_sgs(){
  aws ec2 describe-security-groups --group-id ${group_id} --profile ${profile} --region ${region} --output json | jq -r '.SecurityGroups[].IpPermissions[] | [ ((.FromPort // "")|tostring)+" - "+((.ToPort // "")|tostring), .IpProtocol, .IpRanges[].CidrIp // .UserIdGroupPairs[].GroupId // "" ] | @tsv'
}

function display_referred_sgs(){
	aws ec2 describe-security-groups --filters "Name=ip-permission.group-id,Values=${group_id}" --profile ${profile} --region ${region} --output json | jq -r '.SecurityGroups[].IpPermissions[].UserIdGroupPairs[].GroupId'
}

function display_enis(){
	aws ec2 describe-network-interfaces --filters "Name=group-id,Values=${group_id}" --profile ${profile} --region ${region} | jq -r '.NetworkInterfaces[].NetworkInterfaceId'
}

function display_group_name(){
	aws ec2 describe-security-groups --group-id ${group_id} --profile ${profile} --region ${region} --output json | jq -r '.SecurityGroups[].GroupName'
}

function display_instance_count(){
	aws ec2 describe-instances --filters "Name=instance.group-id,Values=${group_id}" --profile ${profile} --region ${region} --output json | jq -r '.Reservations[].Instances[].InstanceId' | wc -l
}

function delete_security_group(){
	aws ec2 delete-security-group --region ${region} --profile ${profile} --group-id ${group_id}
}

function describe_security_group(){
	aws ec2 describe-security-groups --group-id ${group_id} --profile ${profile} --region ${region}
}

function describe_instances_table(){
	aws ec2 describe-instances --filters "Name=instance.group-id,Values=${group_id}" --profile ${profile} --region ${region} --output json | jq -r '.Reservations[].Instances[] | [ .InstanceId, .State.Name, .LaunchTime, (.Tags[] | select(.Key=="Name").Value) ] | @tsv'
}

function is_db_sg_authorized(){
	aws rds describe-db-security-groups --db-security-group-name ${group_name} --region ${region} --profile ${profile} --output json | jq -r '.DBSecurityGroups[].IPRanges[].Status'
}

function get_sg_vpc_id(){
	aws ec2 describe-security-groups --filters "Name=group-id,Values=${group_id}" --profile ${profile} --region ${region} --output json | jq -r '.SecurityGroups[].VpcId'
}

# Test if jq command line tool is installed (required)
which jq >/dev/null
if [[ $? -ne 0 ]]; then
  echo "The script requires the jq tool, please install it and re-run the script"
  exit 1
fi

# Code
while getopts "g:p:r:" opt; do
  case $opt in
    g)
    gV=${OPTARG}
    group_id=$(echo $gV | tr [:upper:] [:lower:])
    ;;
    p)
    profile=${OPTARG}
    ;;
    r)
    rV=${OPTARG}
    region=$(echo $rV | tr [:upper:] [:lower:])
    ;;
    *)
    usage
    ;;
  esac
done

if [[ $# -lt 6 ]]; then
  echo "Not enough arguments"
  usage
  exit 1
fi

describe_security_group >/dev/null
if [[ $? -eq 0 ]]; then
  group_name=$(display_group_name)
else
  exit 0
fi

vpcid=$(get_sg_vpc_id | sort | uniq)
colyellow "Describing security group \"${group_name}\" attached to vpc \"${vpcid}\""
display_referring_sgs
instances_count=$(display_instance_count)
if [[ ${instances_count} -gt 0 ]]; then
  colyellow "Security group name \"${group_name}\" with id \"${group_id}\" is attached to the following instances:"
  underline "InstanceId              State   LaunchTime                      InstanceName"
  describe_instances_table
else
  echo "Security group \"${group_name}\" with id \"${group_id}\" is not attached to any instances"
	if [[ ${group_name} = "default" ]]; then
		colyellow "Group \"${group_name}\" is the default VPC group and cannot be deleted!"
		exit 0
	fi
  bold "Do you wish to delete group name: \"${group_name}\" id: \"${group_id}\"? [Y/n] "
  read -r answer
  if [[ ${answer} = [yY] ]]; then
    delete_security_group
    if [[ $? -eq 0 ]]; then
      echo "Group name: \"${group_name}\" with id: \"${group_id}\" has been deleted!"
      echo "${group_name} (${group_id})"
    else
      eni=$(display_enis)
      if [[ -n ${eni} ]]; then
        colred "Unable to delete group \"${group_name}\" as it is attached to network interfaces:"
        echo ${eni}
      else
        echo "Unable to delete group \"${group_name}\" as it is referenced in the following groups:"
        display_referred_sgs | sort | uniq
      fi
    fi
  else
    echo "Not deleting security group ${group_name}"
    exit 0
  fi
fi
