#!/bin/bash
# This file expects to get a file with regions and security groups, 1 in each line and delimited by a comma
# Example:
# us-east-1,sg-XXXXX
# eu-central-1,sg-XXXXX
# Place this script in the same folder as the aws-investigate.sh script.
# Script by Itai Ganot, 2020 lel@lel.bz

# Variables
export AWS_PAGER=""
fpnum_tmpfile="/tmp/${securitygroup}_fp.tmp"
sg_tmpfile="/tmp/${sg}.tmp"

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
function bold {
	echo -e -n "${BOLD}$* ${NOCOLOR}\n"
}
function underline {
	echo -e -n "${UNDERLINE}$* ${NOCOLOR}\n"
}

# Script functions
function usage(){
  echo "In order to run over a list of security groups and delete them, run:"
  echo ${basename}${0} -f filename_containing_sgs_and_regions -p aws_profile_name
  echo "In order to run over a list of seucrity groups to investigate, run:"
  echo ${basename}${0} -f filename_containing_sgs_and_regions -p aws_profile_name -i
  exit 1
}
function investigate_sg(){
  ./investigate_sg.sh -r ${region} -p ${profile} -g ${sg}
}
function display_group_name(){
	aws ec2 describe-security-groups --group-id ${sg} --profile ${profile} --region ${region} --output json | jq -r '.SecurityGroups[].GroupName'
}
function delete_referred_sg(){
  group_name=$(display_group_name)
  colgreen "---------------------------------------------------------------------"
  bold "Processing security group ${sg} - ${group_name}"
  # Tries to delete given security group
  aws ec2 delete-security-group --group-id ${sg} --profile ${profile} --region ${region} 2> sg_tmpfile
  # Checks if DependencyViolation error received
  grep -qw "DependencyViolation" sg_tmpfile
  if [[ $? -eq 0 ]]; then
    colyellow "It seems like the secutiry group we're trying to delete is referenced by other security group/s"
    # Gets all security group that has a rule where the source group is the security group that we try to delete
    for securitygroup in $(aws ec2 describe-security-groups --filters "Name=ip-permission.group-id,Values=${sg}" --profile ${profile} --region ${region} --output json  | jq -r '.SecurityGroups[].GroupId'); do
      # for each found seucrity group, delete the rule that contains the source security group that we want to delete
      colyellow "Security group ${securitygroup} contains a rule with the source group that we try to delete - ${sg}"
      # find all rules in a secutiry group that contain the investigated sg in the source of the ingress rule, get their fromport and toport
			aws ec2 describe-security-groups --group-id ${securitygroup} --profile ${profile} --region ${region} --filters "Name=ip-permission.group-id,Values=${sg}" --output json  | jq -r --arg sg $sg  '.SecurityGroups[].IpPermissions[] | select(.UserIdGroupPairs[].GroupId | contains($sg)) | (.FromPort|tostring) + "_" + (.ToPort|tostring) + "_" + .IpProtocol' > ${fpnum_tmpfile}
      fpsnum=$(wc -l ${fpnum_tmpfile} | awk '{print $1}' | sed -e '/^ /d')
      colyellow "There are ${fpsnum} rules containing ${securitygroup} as source security group to delete"
      for line in $(cat ${fpnum_tmpfile}); do
        fp=$(echo $line | awk -F_ '{print $1}')
        tp=$(echo $line | awk -F_ '{print $2}')
        pr=$(echo $line | awk -F_ '{print $3}')
        if [[ ${pr} == -* ]]; then
          aws ec2 revoke-security-group-ingress --group-id ${securitygroup} --protocol ${pr} --source-group ${sg} --profile ${profile} --region ${region}
          if [[ $? -eq 0 ]]; then
            underline "The following rule has been deleted:"
            colgreen "Protocol: All Port: All"
          fi
          continue
        fi
        if [[ ${fp} == -* ]]; then
          aws ec2 revoke-security-group-ingress --group-id ${securitygroup} --protocol ${pr} --port ${fp} --source-group ${sg} --profile ${profile} --region ${region}
          if [[ $? -eq 0 ]]; then
            underline "The following rule has been deleted:"
            colgreen "Port: All Protocol: ${pr}"
          fi
          continue
        fi
        if [[ $fp == $tp ]]; then
          aws ec2 revoke-security-group-ingress --group-id ${securitygroup} --protocol ${pr} --port ${fp} --source-group ${sg} --profile ${profile} --region ${region}
          if [[ $? -eq 0 ]]; then
            underline "The following rule has been deleted:"
            colgreen "Port: ${fp} Protocol: ${pr}"
          fi
        else
          aws ec2 revoke-security-group-ingress --group-id ${securitygroup} --protocol ${pr} --port ${fp}-${tp} --source-group ${sg} --profile ${profile} --region ${region}
          if [[ $? -eq 0 ]]; then
            underline "The following rule has been deleted:"
            colgreen "FromPort: ${fp} ToPort: ${tp} Protocol: ${pr}"
          fi
        fi
      done
    done
  fi
  # Deletes the security group
  aws ec2 delete-security-group --group-id ${sg} --profile ${profile} --region ${region}
  if [[ $? -eq 0 ]]; then
    bold "Security group ${sg} - ${group_name} has been successfully deleted!"
  fi
  rm -f ${sg_tmpfile}
  rm -f ${fpnum_tmpfile}
}

# Arguments handling
while getopts "f:p:i" opt; do
  case $opt in
    f)
    filename=${OPTARG}
    ;;
    p)
    profile=${OPTARG}
    ;;
    i)
    investigate='True'
    ;;
    *)
    usage
    ;;
  esac
done

if [[ $# -lt 4 ]]; then
  usage
fi

# Code
for line in $(cat ${filename}); do
  region=$(echo ${line} | awk -F, '{print $1}')
  sg=$(echo ${line} | awk -F, '{print $2}')
  if [[ $investigate = 'True' ]]; then
    investigate_sg
  else
    delete_referred_sg
  fi
done

