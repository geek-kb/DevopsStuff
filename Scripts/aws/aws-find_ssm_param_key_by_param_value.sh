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
# The script will print to screen the keys and values it's processing but will
# only log correct matches into the log file which is named like so:
# SUPPLIED_VALUE-DATE-TIME.log
# Script by Itai Ganot 2019

function usage(){
  echo "Usage: ${basedir}${0} -p parameter_value_to_find -l parameter_list"
  echo " "
  echo "Optional:                                                         "
  echo "-d                                                        [debug] "
}

if [[ $# -lt 4 ]]; then
  usage
  exit
fi

debug=false

while getopts ":p:l:d" opt; do
  case ${opt} in
    p)
      value_to_find=${OPTARG}
      ;;
    l)
      param_list=${OPTARG}
      ;;
    d)
      debug=true
      ;;
    \?)
      echo "Unknown option: -$OPTARG" >&2; exit 1
      ;;
  esac
done

GREEN=$(tput setaf 2)
CYAN=$(tput setaf 6)
NOCOLOR=$(tput sgr0)
cwd=$(pwd)
date_time=$(date +'%d-%m-%Y_%T' | tr ":" "-")
log=${cwd}/${value_to_find}-${date_time}.log
counter="0"
pid=$$

#touch ${log}
echo "Pid: ${pid}"

for param in $(cat ${param_list}); do
  check_key=$(aws ssm get-parameters --with-decryption --names "${param}" | jq -r ".Parameters[] | .Value")
  if [[ ${check_key} = ${value_to_find} ]]; then
    echo "Value ${value_to_find} found in parameter ${param}" | tee -a ${log}
  fi
  if ${debug}; then
    counter=$(expr ${counter} + 1)
    echo -e "#${counter}: Finished processing {${CYAN}Key${NOCOLOR}:${param},${GREEN}Value${NOCOLOR}:${check_key}}"
  fi
done
