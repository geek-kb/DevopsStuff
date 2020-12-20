#!/bin/bash
# This script finds the latest ami of timescale-db-production instance, starts
# a new instance from it, edits the database name and username so it reflects
# the staging environment details and restarts postgres.
# It then edits the DNS record for timescale-db-staging.company.private and
# updates it with the new instance private IP.
# Script by Itai Ganot lel@lel.bz

# Variables
prod_instance_name="timescale-db-production"
instance_type="t3.small"
key_name="KEYNAME"
sgs_list="SG_ID1 SG_ID2 SG_ID3"
server_name='timescale-db-staging'
todaydate=$(date +"%Y-%m-%d")
local_hour=$(date +"%H")
if [[ $local_hour == 0* ]]; then
  remote_hour="0$(expr $local_hour - 2)" #DST
else
  remote_hour="$(expr $local_hour - 2)" #DST
fi
company_private_hostedzone='company.private'
company_private_hosted_zone_id='ZXXXXXXX'
region='us-west-2'
export AWS_PAGER=""

# Functions
function get_jq(){
	echo "jq not installed, installing..."
	wget -s -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
	chmod +x ./jq
	sudo mv jq /usr/bin/
}

function get_latest_ami {
  latest_db_instance_ami=$(aws ec2 describe-images --region ${region} --filters "Name=tag:Name,Values=${prod_instance_name}" | jq --arg todayhour "${todaydate}T${remote_hour}" -r '.Images[] | select(.CreationDate | startswith($todayhour))| .ImageId')
  if [[ -z ${latest_db_instance_ami} ]]; then
    ((remote_hour--))
    aws ec2 describe-images --region ${region} --filters "Name=tag:Name,Values=${prod_instance_name}" | jq --arg todayhour "${todaydate}T0${remote_hour}" -r '.Images[] | select(.CreationDate | startswith($todayhour))| .ImageId'
  else
    echo $latest_db_instance_ami
  fi
}

# Test if jq command line tool is installed (required) - if not, install it
which jq >/dev/null
if [[ $? -ne 0 ]]; then
  get_jq
fi

# Code
instance_ami=$(get_latest_ami)
if [[ -z $instance_ami ]]; then
  echo "Unable to locate latest ami"
  exit 1
fi
echo "Found latest ami: ${instance_ami}"
new_instance_ip=$(aws ec2 run-instances --region ${region} --image-id ${instance_ami} --instance-type ${instance_type} --key-name ${key_name} --security-group-ids ${sgs_list} --associate-public-ip-address --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${server_name}}]" |\
jq -r '.Instances[].NetworkInterfaces[].PrivateIpAddress')
echo "A new instance created from latest ami id ${instance_ami} with private ip ${new_instance_ip}"
echo "Waiting 1 minute for the new server to become available..."
sleep 60

cat <<EOF >> manage_pg.sh
#!/bin/bash
echo "Renaming database company_prod to company"
sudo su - postgres -c 'psql -c "alter database company_prod rename to company;"' &>/dev/null
echo "Renaming user company_prod to company"
sudo su - postgres -c 'psql -c "alter user company_prod rename to company;"'
echo "Updating postgres user company password"
sudo -u postgres psql -d company -c "alter user company with encrypted password 'company';"
echo "Granting all privileges to user company on database company"
sudo su - postgres -c 'psql -c "grant all privileges on database company to company;"'
echo "Restarting postgres service"
sudo su - -c "systemctl restart postgresql@12-main.service"
EOF

echo "Uploading script to manage postgres to the new instance"
scp -o StrictHostKeyChecking=no manage_pg.sh ubuntu@${new_instance_ip}:/home/ubuntu

echo "Remotely running the script that updates postgres username and db name"
ssh ubuntu@${new_instance_ip} "chmod u+x /home/ubuntu/manage_pg.sh ; ./manage_pg.sh ; rm -f manage_pg.sh ; echo 'postgres server restarted' > postgres_status"

echo "Preparing route53 resource record change"
cat <<EOF >> change-resource-record-sets.json
{
	"Comment": "update ip address",
	"Changes": [{
		"Action": "UPSERT",
		"ResourceRecordSet": {
			"Name": "${server_name}.${company_private_hosted_zone}.",
			"Type": "A",
			"TTL": 360,
			"ResourceRecords": [{
				"Value": "localIp"
			}]
		}
	}]
}
EOF


echo "Updating company.private hosted zone with the new instance ip"
sed -i "s/localIp/${new_instance_ip}/g" change-resource-record-sets.json
aws route53 change-resource-record-sets --hosted-zone-id ${company_private_hosted_zone_id} --change-batch file://change-resource-record-sets.json
rm -f change-resource-record-sets.json manage_pg.sh

sleep 30
echo "The following resource has been updated:"
aws route53 list-resource-record-sets --hosted-zone-id ${company_private_hosted_zone_id} | jq --arg updatedresource "${server_name}.${company_private_hosted_zone}." -r '.ResourceRecordSets[] | select(.Name | contains($updatedresource)) | (.Name|tostring) + "   " + (.ResourceRecords[].Value|tostring)'
_
