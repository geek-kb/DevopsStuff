mkdir -p ~/.aws/
echo [default] > ~/.aws/config
echo aws_access_key_id=ACCESSID >> ~/.aws/config
echo aws_secret_access_key=ACCESSKEY  >> ~/.aws/config
echo region=us-west-2 >> ~/.aws/config
echo output=json >> ~/.aws/config
region=us-west-2
regioncode=or
ServerName=${regioncode}-${Environment}-Analytics1-${BUILD_NUMBER}

pointer=$(aws ec2 describe-instances --region $region | grep -B100 "Angelsense-${Environment}-${BUILD_NUMBER}\"," | grep -B1 hostname | grep analytics1 | awk '{print $2}' | tr -d '\"|,')
analyticsInstanceId=$(aws ec2 describe-instances --region $region | grep -A50 Tags | grep -A40 AngelSense-${Environment}-Analytics-${BUILD_NUMBER} | grep -B1 InstanceId | grep Value | awk '{print $2}' | tr -d '\"|,')
times=0
echo
INSTANCE_NAME=$ServerName
while [ 20 -gt $times ] && ! aws ec2 describe-instance-status --instance-id $analyticsInstanceId | grep ok | awk 'NR==1' | awk '{print $2}' | tr -d '\"|,'
do
  times=$(( $times + 1 ))
  echo Attempt $times at verifying $INSTANCE_NAME is running...
  sleep 20
done

echo

if [ 20 -eq $times ]; then
  echo Instance $pointer is not running. Exiting...
  exit 1;
else
        echo "Instance $pointer is running!"
        sleep 10
        rm -f ~/.aws/config

fi
