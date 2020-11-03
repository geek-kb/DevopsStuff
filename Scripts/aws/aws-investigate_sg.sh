#!/bin/bash

# This tool investigates AWS security groups.
# It accepts the following arguments:
# credentials_profile, region and security_group_id
# It then describes the security group's rules, generates a url to the sg,
# if the sg is attached to any elastic network interfaces it shows these eni's,
# displays security group id's that refer to the investigated sg, checks if any
# instances are attached to this sg and if there are any then they are displayed
# formatted like so: Instance Id, Status, Launch time and Name.
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

# Script functions

function get_jq(){
  echo "jq not installed, installing..."
  wget -s -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
  chmod +x ./jq
  cp jq /usr/bin/
}

function display_sg_rules(){
	colyellow "SG Rules:"
	aws ec2 describe-security-groups --group-id ${group_id} --profile ${profile} --region ${region} --output json | jq -r '.SecurityGroups[].IpPermissions[] | [ ((.FromPort // "")|tostring)+" - "+((.ToPort // "")|tostring), .IpProtocol, .IpRanges[].CidrIp // .UserIdGroupPairs[].GroupId // "" ] | @tsv'
}

function display_referred_sgs(){
	colyellow "Checking if security group \"${group_name}\" is referenced by any other security groups"
	sgref=$(aws ec2 describe-security-groups --filters "Name=ip-permission.group-id,Values=${group_id}" --profile ${profile} --region ${region} --output json | jq -r --arg sgtofind ${group_id} '.SecurityGroups[] | select(.IpPermissions[].UserIdGroupPairs[].GroupId | contains($sgtofind)) | .GroupId' | sort | uniq)
	if [[ -n ${sgref} ]]; then
		echo "Security group \"${group_name}\" is referenced in the following groups:"
		echo ${sgref} | tr " " '\n'
	else
		echo "Security group \"${group_name}\" is not referenced by any other security groups"
	fi
}

function display_enis(){
	colyellow "Checking if SG is attached to any elastic network interfaces"
	eni=$(aws ec2 describe-network-interfaces --filters "Name=group-id,Values=${group_id}" --profile ${profile} --region ${region} | jq -r '.NetworkInterfaces[].NetworkInterfaceId')
	if [[ -n ${eni} ]]; then
		echo "Security group is attached to the following network interfaces:"
		echo ${eni} | tr " " '\n'
	else
		echo "Security group \"${group_name}\" is not attached to any network interfaces"
	fi
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

function generate_sg_link(){
	colyellow "Link to SG:"
	echo "https://${region}.console.aws.amazon.com/ec2/v2/home?region=${region}#SecurityGroup:groupId=${group_id}"
}

function check_sg_attached_lb(){
	colyellow "Checking if security group \"${group_name}\" is attached to a Load Balancer"
	lb_attached_sg=$(aws elb describe-load-balancers --profile ${profile} --region ${region} --output json | jq -r '.LoadBalancerDescriptions[].SecurityGroups[]' | grep ${group_id} | sort | uniq)
	if [[ -n ${lb_attached_sg} ]]; then
		lb_name=$(aws elb describe-load-balancers --profile ${profile} --region ${region} --output json | jq -r --arg group_id ${group_id} '.LoadBalancerDescriptions[] | select(.SecurityGroups[0]==$group_id) | .LoadBalancerName')
		colred "Security group \"${group_name}\" is attached to load balancer: \"${lb_name}\""
	else
		echo "Security group \"${group_name}\" is not attached to any load balancer"
	fi
}

function check_vpc_endpoint(){
	vpcendpoint_sg=$(aws ec2 describe-vpc-endpoints --region ${region} --profile ${profile} | jq -r '.VpcEndpoints[] | ( .Groups[] | select(.GroupId? | startswith("sg-"))).GroupId')
	echo "vpcendpoint_sg: ${vpcendpoint_sg}"
	if [[ ${vpcendpoint_sg}	== ${group_id} ]]; then
		vpcendpoint_type=$(aws ec2 describe-vpc-endpoints --region ${region} --profile $profile | jq -r --arg group_id ${group_id} '.VpcEndpoints[] | ( select(.Groups[].GroupId?==$group_id)) | .VpcEndpointType')
		vpcendpoint_id=$(aws ec2 describe-vpc-endpoints --region ${region} --profile $profile | jq -r --arg group_id ${group_id} '.VpcEndpoints[] | ( select(.Groups[].GroupId?==$group_id)) | .VpcEndpointId')
		echo "Security group name \"${group_name}\" is attached to attached to Vpc Endpoint from type \"${vpcendpoint_type}\" and Id \"${vpcendpoint_id}\""
	fi
}

# Code

# Test if jq command line tool is installed (required) - if not, install it
which jq >/dev/null
if [[ $? -ne 0 ]]; then
  get_jq
fi

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
if [[ $? -eq 0 ]]; then
	colgreen "--------------------------------------------------------------------------"
	bold "Investigating security group \"${group_name}\" with Id \"${group_id}\" in region ${region} attached to vpc \"${vpcid}\""
	display_sg_rules
	generate_sg_link
	display_enis
	display_referred_sgs
	colyellow "Checking if security group \"${group_name}\" is attached to any instances"
	instances_count=$(display_instance_count)
	if [[ ${instances_count} -gt 0 ]]; then
	  colyellow "Security group name \"${group_name}\" with id \"${group_id}\" is attached to the following instances:"
	  underline "InstanceId              State   LaunchTime                      InstanceName"
	  describe_instances_table
	else
	  echo "Security group \"${group_name}\" is not attached to any instances"
		if [[ ${group_name} = "default" ]]; then
			colyellow "Group \"${group_name}\" is the default VPC group and cannot be deleted!"
			exit 0
		fi
		check_sg_attached_lb
	fi
else
	colgreen "--------------------------------------------------------------------------"
	echo "Security group \"${group_name}\" does not exist!"
fi
