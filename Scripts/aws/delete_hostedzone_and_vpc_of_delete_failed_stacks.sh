#!/bin/bash
# After manually (or through aws-cli) changing route53 records of a hosted zone created by Cloud Formation, when you try delete the stack it fails with an error saying:
# "The specified hosted zone contains non-required resource record sets and so cannot be deleted."
# This script will find stacks with "DELETE_FAILED" status, and will recursively delete all the records in the hostedzone and will also delete the VPC.
# It is required as the default limit of number of VPC's per region is 5. Edit the "region_arr" to include the regions which are relevant for you.
# For testing purposes, I've added "echo"s before the commands which may be dangerous [lines 33, 41, 46] to avoid doing any changes and allow you to test the script, so don't forget to remove them before running the script.
# Script by Itai Ganot 2017.
dfstacks_arr=[]
dfshz_arr=[]
region_arr=[]
region_arr=(us-west-2 us-east-1 eu-west-1)
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
NOCOLOR=`tput sgr0`

function colnormal {
	echo -e -n "$YELLOW $* $NOCOLOR\n"
}
function colgood {
	echo -e -n "$GREEN $* $NOCOLOR\n"
}
function colbad {
	echo -e -n "$RED $* $NOCOLOR\n"
}

#region_arr=(eu-west-1)
for region in ${region_arr[@]}; do
	colnormal "-------------- Now working on region $region -----------------"
  colnormal "Finding stacks with status DELETE_FAILED..."
  for stack in $(aws cloudformation list-stacks --stack-status-filter "DELETE_FAILED" --region $region | grep StackName | awk '{print $2}' | tr -d '\"\|,'); do
        colnormal "Getting stack $stack hosted zone id..."
        stackhostedzoneid=$(aws cloudformation describe-stacks --stack-name $stack --region $region | grep -A1 VPCHostedZoneId | grep OutputValue | awk '{print $2}' | tr -d '\"\|,')
				colgood "Found StackHostedZoneId: $stackhostedzoneid"
				echo "--------------------------------------------------------"
        dfshz_arr+=($stackhostedzoneid)
    done
  done

  for l in ${!dfshz_arr[@]}; do
			if [[ $l -gt "0" ]]; then
				echo ""
				colnormal "##############################################################"
  			colgood "Now working on Hostedzone: ${dfshz_arr[$l]}..."
				colnormal "##############################################################"
	      vpcid=$(aws route53 get-hosted-zone --id ${dfshz_arr[$l]} | grep VPCId | awk '{print $2}' | tr -d '\"\|,')
	      aws route53 list-resource-record-sets --hosted-zone-id ${dfshz_arr[$l]} --region $region | jq -c '.ResourceRecordSets[]' | while read -r resourcerecordset; do
	        read -r name type <<<$(echo $(jq -r '.Name,.Type' <<<"$resourcerecordset"))
	        if [ $type != "NS" -a $type != "SOA" ]; then
	          echo aws route53 change-resource-record-sets --region $region \
	          --hosted-zone-id $l \
	          --change-batch '{"Changes":[{"Action":"DELETE","ResourceRecordSet":
	          	'"$resourcerecordset"'
	          }]}' \
	          --output text --query 'ChangeInfo.Id'
	        fi
	      done
	      
				echo aws route53 delete-hosted-zone --region $region \
	      --id ${dfshz_arr[$l]} \
	      --output text --query 'ChangeInfo.Id'
	      if [[ $? -eq "0" ]]; then
	        colgood "Deleting VPC $vpcid of HostedZone ${dfshz_arr[$l]} ..."
	        echo aws ec2 delete-vpc --vpc-id $vpcid --region $region
					if [[ $? -eq "0" ]]; then
						colgood "VPC deleted succssfully!"
						colgood "------------------ End of region $region ---------------------"
						echo "--------------------------------------------------------------"
					else
						colbad "Unable to delete VPC $vpcid in region $region! "
					fi		
	      fi
			fi
	done
