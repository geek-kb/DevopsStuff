#!/bin/bash
# Written by Itai Ganot 2021

server_id='s-XXXXXXXXXX'
s3_bucket_name='a-bucket-name'
whitelist_ips_sg_id='sg-XXXXXXXXXX'
username=${USERNAME}

if [[ -z ${USER_PUBLIC_SSH_KEY} ]]; then
    existing_pub_ssh_key='false'
    echo "Public key not supplied, creating the user without adding its public ssh key"
else
    existing_pub_ssh_key='true'
fi

function usage(){
    echo "This script creates AWS IAM policies and role that are required in order to setup"
    echo "a new customer's directory in the Amazon transfer family (sftp server) of yotpo-cs."
    echo "Usage:"
    echo "${basename}${0} -u UserName"
}

function get_jq(){
	echo "jq not installed, installing..."
	wget -s -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
	chmod +x ./jq
	cp jq /usr/bin/
}

# if [[ $# -ne 2 ]]; then
#     usage
#     echo "No username supplied! exiting!"
#     exit 1
# fi

# while getopts "u:" opt; do
#     case $opt in
#         u)
#         username=${OPTARG}
#         ;;
#         *)
#         usage
#         ;;
#     esac
# done

# Test if jq command line tool is installed (required) - if not, install it
which jq >/dev/null
if [[ $? -ne 0 ]]; then
  get_jq
fi

# AWS Iam - create AWS Transfer assume role policy to attach to the role
cat <<EOF > transfer-assume-role-policy
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "csftpCSFTPUSER",
      "Effect": "Allow",
      "Principal": {
        "Service": "transfer.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

sed -i.bak "s/CSFTPUSER/$username/g" transfer-assume-role-policy

# AWS Iam - create role and attach the above policy to it
aws iam create-role --role-name ${s3_bucket_name}-read-write-${username} --assume-role-policy-document file://transfer-assume-role-policy
rm -f transfer-assume-role-policy

# AWS Iam - create policy to allow user actions on the s3 bucket
cat <<EOF > temp-${s3_bucket_name}-read-write
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ReadWriteS3",
            "Action": [
                "s3:ListBucket"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::S3BUCKETNAME"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:GetObjectACL",
                "s3:PutObjectACL"
            ],
            "Resource": [
                "arn:aws:s3:::S3BUCKETNAME/USERNAME/*"
            ]
        }
    ]
}
EOF
sed -i.bak "s/USERNAME/$username/g" temp-yotpo-cs-ftp-read-write
sed -i.bak "s/S3BUCKETNAME/$s3_bucket_name/g" temp-yotpo-cs-ftp-read-write
aws iam create-policy --policy-name ${s3_bucket_name}-read-write-${username} --policy-document file://temp-yotpo-cs-ftp-read-write
rm -f temp-${s3_bucket_name}-read-write

# AWS Iam - attach the below policies to the new role
policies="yotpo-cs-ftp-scope-down yotpo-cs-ftp-deny-mkdir yotpo-cs-ftp-read-write-${username}"
for policy_name in ${policies}; do
    arn=$(aws iam list-policies --scope Local --output json | jq -r --arg polname ${policy_name} '.Policies[] | select(.PolicyName==$polname) | .Arn')
    echo "Adding ${policy_name} - ${arn} to newly created role yotpo-cs-ftp-read-write-${username}"
    aws iam attach-role-policy --role-name yotpo-cs-ftp-read-write-${username} --policy-arn $arn
done

# AWS Iam - verify the role has been created successfully
aws iam get-role --role-name yotpo-cs-ftp-read-write-${username}

if [[ $? -eq 0 ]]; then
    echo "Role yotpo-cs-ftp-read-write-${username} successfully created!"
    role_arn=$(aws iam get-role --role-name yotpo-cs-ftp-read-write-${username} | jq -r '.Role.Arn')
fi

# AWS S3 - create a folder with the name of the user in the bucket
aws s3api put-object --bucket ${s3_bucket_name} --key ${username}/

# AWS Transfer - creates the user and attaches the role to it
# If the version of AWS-CLI is 2.x then the command should be:
#aws transfer create-user --home-directory /yotpo-cs-ftp/${username} --home-directory-type PATH --role ${role_arn} --server-id ${server_id} --user-name ${username}
# But for version 1.x the command should be:
aws transfer create-user --home-directory /${s3_bucket_name}/${username} --role ${role_arn} --server-id ${server_id} --user-name ${username}

if [[ $? -eq 0 ]]; then
    echo "The following directory has been created for user ${username}:"
    aws transfer describe-user --server-id ${server_id} --user-name ${username}
fi

# If a public ssh key has been provided, add it to the user
if [[ ${existing_pub_ssh_key} == 'true' ]]; then
    aws transfer import-ssh-public-key --server-id ${server_id} --ssh-public-key-body "${USER_PUBLIC_SSH_KEY}" --user-name ${username}
    if [[ $? -eq 0 ]]; then
        echo "Public ssh key has been successfully added to user ${username}"
    fi
fi

echo "Please edit security group ${whitelist_ips_sg_id} in order to add whitelisted IPs thus allowing the newly created user to connect to the sftp server"
