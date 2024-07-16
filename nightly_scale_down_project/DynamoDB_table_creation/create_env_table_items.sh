#!/bin/bash
# This script is used to populate the environments_protection_dynamodb table with the (initial) data from the env_names file using the structure in the environments_protection_dynamodb.json file.
# Script by Itai Ganot, 2022
filename="environments_protection_dynamodb.json"
for env in $(cat env_names); do
  TIMESTAMP=1664799542
  sed -i.bk "s/TIMESTAMP/$TIMESTAMP/g" $filename
  rm -f $filename.bk
  sed -i.ba "s/ENVIRONMENT/$env/" $filename
  rm -f $filename.ba
  export cc="$(cat $filename)"
  echo "--------------------------------------------------------------------"
  aws dynamodb put-item --table-name environments_protection --item \'$cc\'
done
