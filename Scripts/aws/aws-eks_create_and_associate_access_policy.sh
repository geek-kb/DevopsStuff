#!/bin/bash
# This script adds a user or role to the access policy of an EKS cluster and updates the kubeconfig.
# You need to have the AWS CLI installed and configured and jq installed to run this script.
# Required arguments: cluster_name, region, user or role arn
# Script by Itai Ganot, 2024

function stop_script() {
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
        return 1  # Stop if sourced
    else
        exit 1  # Stop if executed
    fi
}
read -r -p "Enter the name of the eks cluster: " cluster_name
read -r -p "Enter the region code: " region
read -r -p "Enter the ARN of the user or role to add to the access policy: " arn
user_or_role=$(echo $arn | rev | cut -d: -f1 | rev | cut -d/ -f1)
if [ "$user_or_role" == "user" ]; then
    object="user"
elif [ "$user_or_role" == "role" ]; then
    object="role"
fi
aws eks list-access-entries --cluster-name $cluster_name --region $region | jq -r '.accessEntries[]' | grep -q $arn && es=0 2>/dev/null || es=1 2>/dev/null
if [ $es -eq 0 ]; then
    echo "The $object already exists in the access policy..."
    read -r -p "Would you like to update your kubeconfig? (y/n): " update_kubeconfig
    if [ "$update_kubeconfig" == "y" ]; then
        aws eks update-kubeconfig --region $region --name $cluster_name
        stop_script
    else
        echo "Exiting..."
        stop_script
    fi
fi
create_output=$(aws eks create-access-entry --cluster-name ${cluster_name} --principal-arn $arn --region $region | jq -r '.accessEntry.createdAt')
if [ -z $create_output ]; then
    echo "An error occurred while adding the $object to the access policy"
    stop_script
fi
opts=$(aws eks list-access-policies | jq -r '.accessPolicies[].name')
# Dynamically populate the list of access policies
options=()
while read -r line; do
    options+=("$line")
done <<EOF
$(echo "$opts")
EOF
options+=("Quit")

echo "Please choose from the list of access policies:"
select choice in "${options[@]}"; do
    if [[ -n $choice ]]; then
        if [[ $choice == "Quit" ]]; then
            echo "Exiting..."
            exit 0
        fi
        echo "You selected: $choice"
        selected_option=$choice
        break
    else
        echo "Invalid choice. Please try again."
    fi
done

policy_full_arn="arn:aws:eks::aws:cluster-access-policy/$selected_option"

echo "Adding the $object to the access policy..."
aws eks associate-access-policy --cluster-name ${cluster_name} \
    --principal-arn $arn \
    --policy-arn $policy_full_arn \
    --access-scope type=cluster \
    --region $region

echo "The $object has been added to the access policy successfully"
echo "Getting sts caller identity..."
aws sts get-caller-identity
echo "Updating kubeconfig..."
aws eks update-kubeconfig --region $region --name $cluster_name
