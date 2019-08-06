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
YELLOW=`tput setaf 3`
NOCOLOR=`tput sgr0`
instancetype="t2.micro"
snid='subnet-04387a60'

function red() {
	echo -e -n "$RED $* $NOCOLOR\n"
}

function green() {
	echo -e -n "$GREEN $* $NOCOLOR\n"
}

function yellow() {
	echo -e -n "$YELLOW $* $NOCOLOR\n"
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

function listSecGroups() {
	aws ec2 describe-security-groups --profile $profile | jq -r '.SecurityGroups[] | "\(.GroupName):\(.GroupId)"'
}

function checkKeyPairs() {
	aws ec2 describe-key-pairs --key-names ${kp} --profile ${profile} &>/dev/null
}

function launchNewInstance() {
	yellow "A new instance with the following details is about to be created:"
	yellow "Instance Type: ${instancetype}"
	yellow "Security Group Id: ${sgi}"
	yellow "Subnet Id: ${snid}"
	yellow "Server Role: ${chosenrole}"
	yellow "Chosen KeyPair: ${kp}"
	read -r -p "Please approve by entering 'yes' or cancel by entering 'no' " answer
	if [[ $answer = 'yes' ]]; then
		rand=$((RANDOM))
		aws ec2 run-instances --image-id ami-0b898040803850657 --count 1 --instance-type ${instancetype} --key-name ${kp} --security-group-ids ${sgi} --subnet-id ${snid} --profile ${profile} --user-data file:///tmp/${chosenrole}.txt > /tmp/$rand.json
		if [[ $? -eq 0 ]]; then
			yellow "Creating..."
			sleep 10
			green "Instance has been created successfully!"
			instanceid=$(cat /tmp/$rand.json | jq -r '.Instances[].InstanceId')
			green "Instance Id: $instanceid"
			green "Instance Public IP: $(aws ec2 describe-instances --instance-id $instanceid --profile $profile | jq -r '.Reservations[].Instances[].NetworkInterfaces[].Association.PublicIp')"
		else
			red "Failed creating instance!"
		fi
	else
		echo "User chose to cancel!"
		exit 0
	fi
}

function createKeyPair() {
	aws ec2 create-key-pair --key-name ${kp} --profile ${profile} | jq -r '.KeyMaterial' > ~/.ssh/${kp}.pem
	chmod 600 ~/.ssh/${kp}.pem
	green "KeyPair ${kp} created and saved in ~/.ssh/${kp}.pem!"
}

function createMysqlUserData() {
	cat <<EOF > /tmp/mysql.txt
#!/bin/bash
yum update -y
yum install -y mariadb-server
systemctl start mariadb
systemctl enable mariadb
EOF
}

function createHttpdUserData() {
	cat <<EOF > /tmp/httpd.txt
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www
chmod 2775 /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;
EOF
}

function createNginxUserData() {
	cat <<EOF > /tmp/nginx.txt
#!/bin/bash
yum update -y
amazon-linux-extras install nginx1.12
systemctl start nginx
systemctl enable nginx
EOF
}

yellow "Please select security group to attach to the new instance"
select sgid in $(listSecGroups); do
	sgi=$(echo ${sgid} | awk -F: '{print $2}')
	break
done

yellow "Please select a role for the new instance"
select role in 'mysql' 'httpd' 'nginx'; do
	chosenrole=${role}
	case $chosenrole in
		mysql)
			createMysqlUserData
			break
		;;
		httpd)
			createHttpdUserData
			break
		;;
		nginx)
			createNginxUserData
			break
		;;
	esac
done

checkKeyPairs
if [[ $? -eq 0 ]]; then
	echo $chosenrole
	launchNewInstance
	exit 0
else
	red "KeyPair ${kp} doesn't exists! creating..."
	createKeyPair
	launchNewInstance
	exit 0
fi
