#!/bin/bash -xe
# Parameterized build - given variables: StackName and Region
# Script by Itai Ganot 2017

logfile="${WORKSPACE}/deploy/jenkins_deploy.log"

function log {
	echo $*
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%S.000Z')]: $*" >> $logfile
}

App=Analytics
app=analytics
applicationName=company-$app

# ASGResourceId
ASGResourceId=$(aws cloudformation describe-stacks --stack-name $StackName --region $region | jq -r '.Stacks[].Outputs[].OutputValue' | grep $StackName-$App)
servers=()
#InstanceId
for instanceid in $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASGResourceId --region $region | jq -r '.AutoScalingGroups[].Instances[].InstanceId'); do 
  privateip=$(aws ec2 describe-instances --instance-id $instanceid --region $region | jq -r '.Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddresses[].PrivateIpAddress')
  servers+=($privateip)
done

servers_count=$(echo ${#servers[@]})


log "###################### Begin #############################################"
log "We're going to deploy version ${Version_VERSION} on $servers_count servers in Auto Scaling Group: $asgname..."
for server in ${servers[@]}; do  
  log "Now deploying on server: $server..."
  scp -o StrictHostKeyChecking=no -i ~/.ssh/company.pem  ${WORKSPACE}/deploy/aws/ops/global/system/deploy-from-nexus.sh company@$server:~/deploy/ ;
  ssh  -oStrictHostKeyChecking=no -i ~/.ssh/company.pem company@$server "chmod +x /home/company/deploy/deploy-from-nexus.sh ; cd /home/company/deploy/ && ./deploy-from-nexus.sh ${Version_VERSION} ${applicationName} $app"
  log "###############- Completed deployment on server: $server! -##############"
done

