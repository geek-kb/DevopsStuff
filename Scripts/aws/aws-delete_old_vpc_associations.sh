#!/bin/bash -e
# This shell script is intended to run as a Jenkins job which checks current available VPC's against VPC's associated to the specified Route53 hosted zone.
crvpc_arr=()
asvpc_arr=()
region="us-west-2"
hostedzoneid="HOSTEDZONEID"
for currentvpc in $(aws ec2 describe-vpcs --region $region| grep VpcId | awk '{print $2}' | tr -d '\"|,'); do crvpc_arr+=($currentvpc); done
for asvpc in $(aws route53 get-hosted-zone --id $hostedzoneid --region $region| grep VPCId | awk '{print $2}' | tr -d '\"|,'); do asvpc_arr+=($asvpc); done
deadvpcs_arr=()
for i in "${asvpc_arr[@]}"; do
    skip=
    for j in "${crvpc_arr[@]}"; do
        [[ $i == $j ]] && { skip=1; break; }
    done
    [[ -n $skip ]] || deadvpcs_arr+=("$i")
done

if [[ "$action" = "dry-run" ]]; then
	for deadvpc in ${!deadvpcs_arr[@]}; do
		echo "Vpc ${deadvpcs_arr[$deadvpc]} is associated to the zone but does not exist! Should be deleted!"
    done
elif [[ "$action" = "delete" ]]; then
	for deadvpc in ${!deadvpcs_arr[@]}; do
    	echo "Vpc ${deadvpcs_arr[$deadvpc]} is associated to the zone but does not exist! Deleting!"
		aws route53 disassociate-vpc-from-hosted-zone --hosted-zone-id $hostedzoneid --vpc VPCRegion=$region,VPCId=${deadvpcs_arr[$deadvpc]}
	done
fi
