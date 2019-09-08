#!/bin/bash

while getopts "sa" opt; do
	case $opt in
		s)select='true'
		;;
		a)all='true'
		;;
		*)exit 1
		;;
	esac
done

if [[ $select = 'true' ]]; then
	select option in 'PublicIp' 'PrivateIpAddress' 'PublicDnsName'; do
		case $option in
			"PublicIp")
				echo "User chose $option"
				aws ec2 describe-instances --profile intcollege_itaig | jq -r --arg OPTION "$option" '.Reservations[].Instances[].NetworkInterfaces[].Association | .[$OPTION]'
				break
				;;
			"PrivateIpAddress")
				echo "User chose $option"
				aws ec2 describe-instances --profile intcollege_itaig | jq -r --arg OPTION "$option" '.Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddresses[] | .[$OPTION]'
				break
				;;
			"PublicDnsName")
				echo "User chose $option"
				aws ec2 describe-instances --profile intcollege_itaig | jq -r --arg OPTION "$option" '.Reservations[].Instances[].NetworkInterfaces[].Association | .[$OPTION]'
				break
				;;
			esac
	done
fi

if [[ $all = 'true' ]]; then
	echo "User chose all"
	aws ec2 describe-instances --profile intcollege_itaig | jq -r '.Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddresses[] | "\(.Association.PublicIp) \(.PrivateIpAddress) \(.Association.PublicDnsName) "'
fi
