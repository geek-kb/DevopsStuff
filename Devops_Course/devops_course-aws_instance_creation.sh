#!/bin/bash

function usage() {
	echo "Usage: ${basename}${0} -k keypair_name -p aws_profile_name"
}

if [[ $# -lt 4 ]]; then
	usage
	exit 1
fi

RED=`tput setaf 1`
GREEN=`tput setaf 2`
NOCOLOR=`tput sgr0`

function red() {
	echo -e -n "$RED $* $NOCOLOR\n"
}

function green() {
	echo -e -n "$GREEN $* $NOCOLOR\n"
}

while getopts "k:p:" opt; do
	case $opt in
		k)kp=${OPTARG}
			;;
		p)profile=${OPTARG}
			;;
		*)usage
			exit 1
			;;
	esac
done

sn='subnet-04387a60'

function listSecGroups() {
	aws ec2 describe-security-groups --profile $profile | jq -r '.SecurityGroups[] | "\(.GroupName):\(.GroupId)"'
}

function checkKeyPairs() {
	aws ec2 describe-key-pairs --key-names ${kp} --profile ${profile} &>/dev/null
}

function launchNewInstance() {
	rand=$((RANDOM))
	aws ec2 run-instances --image-id ami-0b898040803850657 --count 1 --instance-type t2.micro --key-name ${kp} --security-group-ids ${sgi} --subnet-id ${sn} --profile ${profile} > /tmp/$rand.json
	if [[ $? -eq 0 ]]; then
		green "Instance has been created successfully!"
		instanceid=$(cat /tmp/$rand.json | jq -r '.Instances[].InstanceId')
		green "Instance Id: $instanceid"
	else
		red "Failed creating instance!"
	fi
}

function createKeyPair() {
	aws ec2 create-key-pair --key-name ${kp} --profile ${profile} | jq -r '.KeyMaterial' > ~/.ssh/${kp}.pem
	chmod 600 ~/.ssh/${kp}.pem
	green "KeyPair ${kp} created and saved in ~/.ssh/${kp}.pem!"
}

select sgid in $(listSecGroups); do
	sgi=$(echo ${sgid} | awk -F: '{print $2}')

	checkKeyPairs
	if [[ $? -eq 0 ]]; then
		launchNewInstance
		exit 0
	else
		red "KeyPair ${kp} doesn't exists! creating..."
		createKeyPair
		launchNewInstance
		exit 0
	fi
done
