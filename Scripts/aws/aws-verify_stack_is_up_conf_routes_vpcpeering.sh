#!/bin/bash
# This code runs at the end of a Jenkins job which builds AWS CloudFormation stacks.
# It waits for a machine from the stack to start and then configures VPC peering, routes and compiles a list of new stack related servers and starts the application on them parallely.
# Itai Ganot 2017
mkdir -p ~/.aws/
echo [default] > ~/.aws/config
echo aws_access_key_id=AWSACCESSKEYID >> ~/.aws/config
echo aws_secret_access_key=AWSACCESSKEY  >> ~/.aws/config
echo region=us-west-2 >> ~/.aws/config
echo output=json >> ~/.aws/config
region=us-west-2

pointer=$(aws ec2 describe-instances --region $region | grep -B100 "Company-${Environment}-${BUILD_NUMBER}\"," | grep -B1 hostname | grep analytics1 | awk '{print $2}' | tr -d '\"|,')
analyticsInstanceId=$(aws ec2 describe-instances --region $region | grep -A50 Tags | grep -A40 Company-${Environment}-Analytics-${BUILD_NUMBER} | grep -B1 InstanceId | grep Value | awk '{print $2}' | tr -d '\"|,')
times=0
echo

while [ 20 -gt $times ] && ! aws ec2 describe-instance-status --instance-id $analyticsInstanceId | grep ok | awk 'NR==1' | awk '{print $2}' | tr -d '\"|,'
do
  times=$(( $times + 1 ))
  echo Attempt $times at verifying $pointer is running...
  sleep 20
done

echo

if [ 20 -eq $times ]; then
  echo Instance $pointer is not running. Exiting...
  exit 1;
else
        echo "Instance $pointer is running!"
        stackcreated=true
        sleep 10
fi

# Download script which locally edits supervisord and parallel ssh script
aws s3 cp s3://company-ci-files/set_autostart_true_supervisord.sh .
aws s3 cp s3://company-ci-files/ops/paraexec.sh .
chmod +x set_autostart_true_supervisord.sh paraexec.sh
rm -f servers.list
touch servers.list

# Gets hostnames of servers in the new stack
defaultVpcHostedZoneId="XXXXXXXXX"
defaultVpcId="vpc-XXXXXXX"
defVpcRouteTableId="rtb-XXXXXXX"
stackName="Company-${Environment}-${BUILD_NUMBER}"
stackHostedZoneId=$(aws cloudformation describe-stacks --stack-name $stackName | grep -A2 VPCHostedZoneId | grep "OutputValue" | awk '{print $2}' | tr -d "\"")
stackVpcId=$(aws cloudformation describe-stacks --stack-name  $stackName | grep -A1 '"VPC",' | grep OutputValue | awk '{print $2}' | tr -d "\"")
VpcPeerConnId=$(aws ec2 describe-vpc-peering-connections --filters Name=status-code,Values=active | grep -B5 $stackVpcId | grep pcx | awk '{print $2}' | tr -d '\"|,')
stackVpcCidr=$(aws ec2 describe-vpcs --vpc-id $stackVpcId | grep Cidr | awk '{print $2}' | tr -d '\"|,')
  if $(aws ec2 describe-route-tables | grep -q blackhole) ; then # Find a route which leads to a dead VpcPeeringId
    # Delete route to blackhole
    aws ec2 delete-route --route-table-id $defVpcRouteTableId --destination-cidr-block $stackVpcCidr || true
    # Add route for the new stack
    aws ec2 create-route --destination-cidr-block $stackVpcCidr --route-table-id $defVpcRouteTableId --vpc-peering-connection-id $VpcPeerConnId
  else
    # Add route for the new stack
    aws ec2 create-route --destination-cidr-block $stackVpcCidr --route-table-id $defVpcRouteTableId --vpc-peering-connection-id $VpcPeerConnId || true
    echo "No dead peerings found"
  fi

  for hostname in $(aws route53 list-resource-record-sets --hosted-zone-id $stackHostedZoneId | grep -i $stackVpcId | grep [1-9] | grep -v "cass\|mysql\|kafka\|api3\|api4" | awk -F: '{print $2}' | tr -d '\"|,' | sed 1,2d); do
    hn=$(echo $hostname | sed 's/.$//')
                echo $hn
                echo $hn >> servers.list
    case $hn in
      *"batch"*)
        app=batch
      ;;
      *"api"*)
        app=api
      ;;
      *"analytics"*)
        app=analytics
      ;;
    esac
                scp -i ~/.ssh/company.pem -o StrictHostKeyChecking=no set_autostart_true_supervisord.sh Company@$hostname:~/
                ssh -i ~/.ssh/company.pem -o StrictHostKeyChecking=no Company@$hostname "/home/Company/set_autostart_true_supervisord.sh ; echo $hostname:  ;grep -A6 program:Company-$app  /etc/supervisord.conf | grep autostart"
done
./paraexec servers.list "/home/Company/startApp.sh"

rm -f ~/.aws/config ~/set_autostart_true_supervisord.sh

