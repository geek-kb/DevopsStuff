#!/bin/bash
# This script expects an AWS SSM parameter value and a list containing
# (SecureString) paramter names and then runs on the list and checking which
# parameter keys contain the supplied parameter value.
# A possible way to compile parameters name list is to run:
# aws ssm describe-parameters | jq -r ".Parameters[].Name" > all_params
#
# When to use this script? When you want to check if there's more than one
# paramter key which contains the same parameter value.
#
# The script will print to scrren the keys and values it's processing but will
# only log correct matches into the log file which is named like so:
# SUPPLIED_VALUE-DATE-TIME.log
# Script by Itai Ganot 2019

function usage(){
  echo "Usage: ${basedir}${0} parameter_value_to_find parameters_list"
}

if [[ $# -lt "2" ]]; then
  usage
  exit
fi

GREEN=$(tput setaf 2)
CYAN=$(tput setaf 6)
NOCOLOR=$(tput sgr0)
value_to_find=$1
param_list=$2
cwd=$(pwd)
date_time=$(date +'%d-%m-%Y_%T' | tr ":" "-")
log=${cwd}/${value_to_find}-${date_time}.log
counter="0"
touch $log

for param in $(cat ${param_list}); do
  check_key=$(aws ssm get-parameters --with-decryption --names "${param}" | jq -r ".Parameters[] | .Value")
  if [[ ${check_key} = ${value_to_find} ]]; then
    echo "Value ${value_to_find} found in parameter ${param}" | tee -a ${log}
  fi
  counter=$(expr ${counter} + 1)
  echo -e "#${counter}: Finished processing {${CYAN}Key${NOCOLOR}:${param},${GREEN}Value${NOCOLOR}:${check_key}}"
done

