#!/bin/bash
# This script runs on a list containing AWS hosted zone ids and replacing old values with new ones (old: $old_value, new: $new_val1, $new_val2) by replacing the relevant values in the upsert.json file:
#{
#  "Comment": "string",
#  "Changes": [
#    {
#      "Action": "UPSERT",
#      "ResourceRecordSet": {
#        "Name": "ResourceName",
#        "Type": "CNAME",
#        "TTL": 60,
#        "ResourceRecords": [
#          {
#            "Value": "ResourceValue"
#          }
#        ]
#        }
#      }
#  ]
#}
# I've used cli53 to export all hosted zone id's to a list which the script accepts.
# Edit script variables before running!
# Script by Itai Ganot 2018

RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
NOCOLOR=`tput sgr0`

function yellow {
  echo -e -n "$YELLOW $* $NOCOLOR\n"
}
function green {
  echo -e -n "$GREEN $* $NOCOLOR\n"
}
function red {
  echo -e -n "$RED $* $NOCOLOR\n"
}

# Vars
changeBatchFile="./upsert.json"
hostsfile="./all_zones"
old_value="staging-renderer-274511656"
new_val1="staging.DOMAINNAME.com"
new_val2="m.staging.DOMAINNAME.com"

# Back up the files we're working on
cp $changeBatchFile{,.bak}
cp $hostsfile{,.bak}

hostscount=$(wc -l < $hostsfile | awk '{$1=$1};1')
red "The are $hostscount hosted-zone-id's to query"
counter="1"

for zoneId in $(cat $hostsfile); do
  if [[ ${zoneId} != "Z35SXDOTRQ7X7K" ]]; then # If zone is DOMAINNAME.com, skip
    zoneName=$(aws route53 get-hosted-zone --id $zoneId | jq -r '.HostedZone.Name')
    for resource in $(aws route53 list-resource-record-sets --hosted-zone-id $zoneId | jq -r --arg pattern $old_value '.ResourceRecordSets[]? | select(.ResourceRecords[]?.Value | contains($pattern)) | .Name'); do
      # Finds all resources that contain the old staging-renderer in the resource value
      yellow "Now querying ${resource} in zone $zoneId - $zoneName"
      case ${resource} in
        staging*)
        red "---------------- $counter --------------"
        echo "starts with staging"
        sed -i.bak-${zoneId} "s/ResourceName/${resource}/g" $changeBatchFile
        sed -i.bak-${zoneId} "s/ResourceValue/${new_val1}/g" $changeBatchFile
        yellow "The following changes are going to be applied:"
        cat $changeBatchFile
        aws route53 change-resource-record-sets --hosted-zone-id $zoneId --change-batch file://$changeBatchFile
        cp ${changeBatchFile}.bak $changeBatchFile
        cp ${hostsfile}.bak $hostsfile
        let "counter+=1"
        ;;
        m.staging*)
        red "---------------- $counter --------------"
        echo "starts with m.staging"
        sed -i.bak-${zoneId} "s/ResourceName/${resource}/g" $changeBatchFile
        sed -i.bak-${zoneId} "s/ResourceValue/${new_val2}/g" $changeBatchFile
        yellow "The following changes are going to be applied:"
        cat $changeBatchFile
        aws route53 change-resource-record-sets --hosted-zone-id $zoneId --change-batch file://$changeBatchFile
        cp ${changeBatchFile}.bak $changeBatchFile
        cp ${hostsfile}.bak $hostsfile
        let "counter+=1"
        ;;
      esac
    done
  else
    red "not touching DOMAINNAME.com!"
  fi
done

red "$(expr $counter - 1) hosts have been processed!"
