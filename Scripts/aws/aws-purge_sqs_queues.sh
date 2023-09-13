#!/bin/bash
export AWS_PAGER=""

function usage(){
echo "This script lists and purges a given queue url"
echo "Available switches:"
echo "-e	Stage name (Mandatory, exaple stg, prd)"
echo "-l	Lists all queues"
echo "-q	Queue name (taken from output of list)"
echo "Usage example:"
echo "Displays a list of queue names per the given environment"
echo "./purge_queues.sh -e stg -l"
echo "Select and copy the relevant queue name and run the following command:"
echo "./purge_queues.sh -e stg -q queue_name"
echo " "
}

function get_jq(){
	echo "jq not installed, installing..."
	wget -s -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
	chmod u+x ./jq
	cp jq /usr/local/bin/
}

which -s jq
if [[ $? -ne 0 ]]; then
	get_jq
fi

list='false'
if [[ $# -eq 0 ]]; then
	echo "Not enough parameters have been passed!"
	echo " "
	usage
	exit 1
fi
while getopts "lq:e:" opt; do
	case $opt in
		l)
		list='true'
		;;
		q)
		queue_name=${OPTARG}
		;;
		e)
		env=${OPTARG}
		;;
		*)
		usage
		;;
	esac
done

if [[ -z $list && -z $env ]]; then
	usage
	exit 1
fi
if [[ $env == 'stg' ]]; then
	acc_id='STG_ACCOUNT_ID'
	region='eu-west-2'
elif [[ $env == 'prd' ]]; then
	acc_id='PRD_ACCOUNT_ID'
	region='us-east-1'
fi	
queue_url=https://sqs.${region}.amazonaws.com/${acc_id}/${queue_name}
if [[ $list == 'true' ]]; then
	aws sqs list-queues --region $region | jq -r '.QueueUrls[]' | rev | awk -F/ '{print $1}' | rev
elif [[ $list == 'false' ]]; then
	aws sqs purge-queue --region $region --queue-url ${queue_url}
fi

