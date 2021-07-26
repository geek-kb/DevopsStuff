#!/bin/bash

server_id='s-XXXXXXXXXX'
s3_bucket_name='company-cs-ftp'
whitelist_ips_sg_id='sg-XXXXXXXXXX'
customer_directory_name=${CUSTOMER_DIRECTORY_NAME}

if [[ -z ${USER_PUBLIC_SSH_KEY} ]]; then
    existing_pub_ssh_key='false'
    echo "Public key not supplied, creating the user without adding its public ssh key"
else
    existing_pub_ssh_key='true'
fi

function usage(){
    echo "This script creates AWS IAM policies and role that are required in order to setup"
    echo "a new customer's directory in the Amazon transfer family (sftp server) of company-cs."
    echo "Usage:"
    echo "${basename}${0} -u UserName"
}

function get_jq(){
	echo "jq not installed, installing..."
	wget -s -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
	chmod +x ./jq
	cp jq /usr/bin/
}

# Test if jq command line tool is installed (required) - if not, install it
which jq >/dev/null
if [[ $? -ne 0 ]]; then
  get_jq
fi

dir_name=$(aws transfer list-users --server-id ${server_id} | jq -r --arg dirname ${customer_directory_name} '.Users[] | select(.HomeDirectory | contains($dirname)) .HomeDirectory' | cut -d"/" -f3)
if [[ ${dir_name} == ${customer_directory_name} ]]; then
    echo "Customer directory name \"${customer_directory_name}\" already exists!"
    echo "Exiting!"
    exit 1
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

sed -i.bak "s/CSFTPUSER/$customer_directory_name/g" transfer-assume-role-policy

# AWS Iam - create role and attach the above policy to it
aws iam create-role --role-name ${s3_bucket_name}-read-write-${customer_directory_name} --assume-role-policy-document file://transfer-assume-role-policy
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
sed -i.bak "s/USERNAME/$customer_directory_name/g" temp-company-cs-ftp-read-write
sed -i.bak "s/S3BUCKETNAME/$s3_bucket_name/g" temp-company-cs-ftp-read-write
aws iam create-policy --policy-name ${s3_bucket_name}-read-write-${customer_directory_name} --policy-document file://temp-company-cs-ftp-read-write
rm -f temp-${s3_bucket_name}-read-write

# AWS Iam - attach the below policies to the new role
policies="company-cs-ftp-scope-down company-cs-ftp-deny-mkdir company-cs-ftp-read-write-${customer_directory_name}"
for policy_name in ${policies}; do
    arn=$(aws iam list-policies --scope Local --output json | jq -r --arg polname ${policy_name} '.Policies[] | select(.PolicyName==$polname) | .Arn')
    echo "Adding ${policy_name} - ${arn} to newly created role company-cs-ftp-read-write-${customer_directory_name}"
    aws iam attach-role-policy --role-name company-cs-ftp-read-write-${customer_directory_name} --policy-arn $arn
done

# AWS Iam - verify the role has been created successfully
aws iam get-role --role-name company-cs-ftp-read-write-${customer_directory_name}

if [[ $? -eq 0 ]]; then
    echo "Role company-cs-ftp-read-write-${customer_directory_name} successfully created!"
    role_arn=$(aws iam get-role --role-name company-cs-ftp-read-write-${customer_directory_name} | jq -r '.Role.Arn')
fi

# AWS S3 - create a folder with the name of the user in the bucket
aws s3api put-object --bucket ${s3_bucket_name} --key ${customer_directory_name}/

# AWS Transfer - creates the user and attaches the role to it
# If the version of AWS-CLI is 2.x then the command should be:
#aws transfer create-user --home-directory /company-cs-ftp/${customer_directory_name} --home-directory-type PATH --role ${role_arn} --server-id ${server_id} --user-name ${customer_directory_name}
# But for version 1.x the command should be:
aws transfer create-user --home-directory /${s3_bucket_name}/${customer_directory_name} --role ${role_arn} --server-id ${server_id} --user-name ${customer_directory_name}

if [[ $? -eq 0 ]]; then
    echo "The following directory has been created for user ${customer_directory_name}:"
    aws transfer describe-user --server-id ${server_id} --user-name ${customer_directory_name}
fi

# If a public ssh key has been provided, add it to the user
if [[ ${existing_pub_ssh_key} == 'true' ]]; then
    aws transfer import-ssh-public-key --server-id ${server_id} --ssh-public-key-body "${USER_PUBLIC_SSH_KEY}" --user-name ${customer_directory_name}
    if [[ $? -eq 0 ]]; then
        echo "Public ssh key has been successfully added to user ${customer_directory_name}"
    fi
fi

echo "Please edit security group ${whitelist_ips_sg_id} in order to add whitelisted IPs thus allowing the newly created user to connect to the sftp server"

