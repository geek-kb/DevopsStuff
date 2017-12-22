#!/bin/bash -xe

logfile="${WORKSPACE}/deploy/jenkins_deploy.log"

function log {
	echo $*
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%S.000Z')]: $*" >> $logfile
}

admins="itaig hanan"

StackEnvType=$(echo $StackName | awk -F- '{print $2}')
stackenvtype=$(echo ${StackEnvType} | tr [:upper:] [:lower:])

#BuildUser=$(curl -s --insecure -u ${J_USER}:${J_PASS} ${BUILD_URL}/api/json | jq -r '.actions[].causes[]?.userId? | select(.)')

#if [[ $StackEnvType == "Prd" && ! BuildUser ~= $admins ]]; then
#	echo "You are not allowed to deploy to Production environment!"
#	exit 1
#fi

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
  if [[ ${autostart} == "Yes" ]]; then
  	ssh  -oStrictHostKeyChecking=no -i ~/.ssh/company.pem company@$server "chmod +x /home/company/deploy/deploy-from-nexus.sh ; cd /home/company/deploy/ && ./deploy-from-nexus.sh ${Version_VERSION} ${applicationName} $app "
  	log "###############- Completed deployment on server: $server! -################"
  else
  	ssh  -oStrictHostKeyChecking=no -i ~/.ssh/company.pem company@$server "chmod +x /home/company/deploy/deploy-from-nexus.sh ; cd /home/company/deploy/ && ./deploy-from-nexus.sh ${Version_VERSION} ${applicationName} $app false"
  	echo "###############- Don't forget to start the application on server: $server! -##############"
  fi
done

rm -rf target
rm -f servers.txt
mkdir target
echo ${Version_VERSION} > target/${stackenvtype}_${app}_version.txt

aws s3 cp target/${stackenvtype}_${app}_version.txt s3://company-ci-files/app_versions/${stackenvtype}_${app}_version.txt --region us-west-2
if [[ $? -eq "0" ]]; then
	echo "version file uploaded successfully to app_version on S3!"
else
	echo "Unable to upload version file to S3 bucket!"
    exit 1
fi
