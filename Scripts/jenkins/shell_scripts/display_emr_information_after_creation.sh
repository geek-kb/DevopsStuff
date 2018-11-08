#!/bin/bash
# Itai Ganot
# This script displays information after the creation of a new EMR cluster using the job "EMR_Cluster_creation"
# The script expects a Cloud Formation Stack Name"
stackName=$1
if [[ -z $stackName ]]; then
  echo "Please provide stack name"
  exit 1
fi
RED=$(tput setaf 1)
NOCOLOR=$(tput sgr0)
function col {
  echo -e -n "$RED $* $NOCOLOR\n"
}
region=us-east-1
clusterId=$(aws cloudformation describe-stack-resource --stack-name $stackName --logical-resource-id EMRCluster --region $region| jq -r '.StackResourceDetail.PhysicalResourceId')
echo "clusterId: $clusterId"
masterDnsName=$(aws emr describe-cluster --cluster-id $clusterId --region $region | jq -r '.Cluster.MasterPublicDnsName')
echo "masterDnsName: $masterDnsName"
if [[ $masterDnsName == *"amazonaws.com"* ]]; then
  masterIp=$(aws emr list-instances --cluster-id $clusterId --region $region | jq -r --arg MASTERDNS "$masterDnsName" '.Instances[] | select(.PublicDnsName==$MASTERDNS) | .PrivateIpAddress')
else
  masterIp=$(aws emr describe-cluster --cluster-id $clusterId --region $region | jq -r '.Cluster.MasterPublicDnsName' | awk -F. '{print $1}' | sed -e 's/^ip-//g' | tr "-" ".")
fi
echo "masterIp: $masterIp"
masterInstanceId=$(aws emr list-instances --cluster-id $clusterId --region $region | jq -r --arg MASTERIP "$masterIp" '.Instances[] | select(.PrivateIpAddress==$MASTERIP) |.Ec2InstanceId')
echo "masterInstanceId: $masterInstanceId"
masterInstanceKeyName=$(aws ec2 describe-instances --instance-id $masterInstanceId --region $region | jq -r '.Reservations[].Instances[].KeyName')
echo "masterInstanceKeyName: $masterInstanceKeyName"

col "================================================================================"
col "In order to connect to the server by ssh, use: "
col "ssh -i ${masterInstanceKeyName}.pem hadoop@$masterIp"
col "Resource Manager can be accessed from the following url: http://$masterIp:8088"
col "HDFS Name Node: http://$masterIp:50070"
col "================================================================================"
