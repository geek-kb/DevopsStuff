#!/bin/bash
# This script expects a SSM parameter list and then goes through the list and
# updates each parameter from list with the provided value.
# The script is being used in the aws-iam-key-rotation project
# Script by Itai Ganot
function usage(){
  echo "$basename$0 -p param_list -v value -t type -e env [ -o ]"
  echo "Types can be:"
  echo "String, StringList, SecureString"
  echo "By default the script will execute a dry-run, use -o to overwrite exiting parameter"
}

function exitCode(){
  if [[ $? -ne 0 ]]; then
    echo "Error, command failed!"
    exit 1
  else
    message="Inserted value ${value} to parameter ${param} in ${env} environment."
    echo $message
  fi
}
overwrite=false

if [[ $# -lt 4 ]]; then
  usage
  exit 1
fi

while getopts "p:v:t:e:o" opt; do
  case ${opt} in
    p)
      param_list=$OPTARG
      ;;
    v)
      value=$OPTARG
      ;;
    t)
      key_type=$OPTARG
      ;;
    e)
      env=$OPTARG
      if [[ $env = "staging" ]]; then
        env_name="staging"
      elif [[ $env = "production" ]]; then
        env_name="production"
      fi
      key_id="alias/param_key_${env_name}"
      ;;
    o)
      overwrite=true
      ;;
    \?)
      usage
      exit 1
      ;;
    esac
done

for param in $(cat $param_list); do
  if [[ ${overwrite} != true ]]; then
    aws ssm put-parameter --name ${param} --value ${value} --type SecureString --key-id ${key_id}
    exitCode
  else
    aws ssm put-parameter --name ${param} --value ${value} --type SecureString --key-id ${key_id} --overwrite
    exitCode
  fi
done
