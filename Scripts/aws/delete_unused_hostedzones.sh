#!/bin/bash
# This script runs through all used regions, identifies the stacks which are currently in use and flags them as protected, for all the rest of the stacks, it catches their HostedZoneId and then cleans all hosts from the zoneid and then deletes the zoneid itself.

OregonprotectedZones=[]
OrRegion="us-west-2"
IrelandprotectedZones=[]
IrRegion="eu-west-1"
VirginiaprotectedZones=[]
ViRegion="us-east-1"
AllProtected=[]

for Ostack in $(aws cloudformation list-stacks --stack-status-filter "CREATE_COMPLETE" --region $OrRegion | grep StackName | awk -F: '{print $2}' | sort | tr -d '\"\|,' | tr -d ' '); do
	for Ohostedzone in $(aws cloudformation describe-stacks --stack-name $Ostack | grep -A1 VPCHostedZoneId | grep OutputValue | awk '{print $2}' | tr -d '\"\|,'); do
		OregonprotectedZones+=($Ohostedzone)
	done
done


for Istack in $(aws cloudformation list-stacks --stack-status-filter "CREATE_COMPLETE" --region $IrRegion | grep StackName | awk -F: '{print $2}' | sort | tr -d '\"\|,' | tr -d ' '); do
	for Ihostedzone in $(aws cloudformation describe-stacks --stack-name $Istack --region $IrRegion | grep -A1 VPCHostedZoneId | grep OutputValue | awk '{print $2}' | tr -d '\"\|,'); do
		IrelandprotectedZones+=($Ihostedzone)
	done
done


for Vstack in $(aws cloudformation list-stacks --stack-status-filter "CREATE_COMPLETE" --region $ViRegion | grep StackName | awk -F: '{print $2}' | sort | tr -d '\"\|,' | tr -d ' '); do
	for Vhostedzone in $(aws cloudformation describe-stacks --stack-name $Vstack --region $ViRegion | grep -A1 VPCHostedZoneId | grep OutputValue | awk '{print $2}' | tr -d '\"\|,'); do
		VirginiaprotectedZones+=($Vhostedzone)
	done
done

for i in ${!OregonprotectedZones[@]}; do
	if [[ $i -ne 0 ]]; then
		AllProtected+=(${OregonprotectedZones[$i]})
	fi
done

for i in ${!IrelandprotectedZones[@]}; do
	if [[ $i -ne 0 ]]; then
		AllProtected+=(${IrelandprotectedZones[$i]})
	fi
done

for i in ${!VirginiaprotectedZones[@]}; do
	if [[ $i -ne 0 ]]; then
		AllProtected+=(${VirginiaprotectedZones[$i]})
	fi
done

echo "Protected zones:"
for i in ${!AllProtected[@]}; do
	if [[ $i -ne 0 ]]; then
		echo "${AllProtected[$i]}"
	fi
done

for hostedzone in $(aws route53 list-hosted-zones | jq -c '.HostedZones[]' | grep -v "angelsense\.com\|angelsense\.co\.il\|angelsense-private" | awk -F/ '{print $3}' | awk -F"\"" '{print $1}'); do
	if [[ ! "${AllProtected[@]}" == *"$hostedzone"* ]]; then
		echo "Hostedzone $hostedzone is not protected"
		echo "Removing all resource records in hostedzone $hostedzone and deleting zone..."
		aws route53 list-resource-record-sets --hosted-zone-id $hostedzone | jq -c '.ResourceRecordSets[]' | while read -r resourcerecordset; do
			read -r name type <<<$(echo $(jq -r '.Name,.Type' <<<"$resourcerecordset"))
			if [ $type != "NS" -a $type != "SOA" ]; then
			aws route53 change-resource-record-sets \
			  --hosted-zone-id $hostedzone \
			  --change-batch '{"Changes":[{"Action":"DELETE","ResourceRecordSet":
					'"$resourcerecordset"'
				}]}' \
			  --output text --query 'ChangeInfo.Id'
			fi
		done
	aws route53 delete-hosted-zone \
  --id $hostedzone \
  --output text --query 'ChangeInfo.Id'

	else
		echo "Hostedzone $hostedzone is protected"
	fi
done
