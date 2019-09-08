#!/bin/bash
# This script runs through a given directory in s3 redis backups bucket, finds all backups older than 14 days and earlier than
# 90 days, keeps backups of one hour per those days and deleting the rest of the backups of each day.

todayDate=$(date +'%Y-%m-%d')
chosenBackupHour=000000
bucketName='company-redis-dr'

declare -a arr

function usage(){
  yellow "----------------------------------------------------------------"
  yellow "# Usage: ${basename}${0} redis_database_name         #"
  yellow "# Available redis database names:                              #"
  yellow "# rofb                 (PROD-ROFB)                             #"
  yellow "# tier-3               (rof2)                                  #"
  yellow "# rof4                 (ROF4)                                  #"
  yellow "# rof5                 (ROF5)                                  #"
  yellow "----------------------------------------------------------------"
}

RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
PURPLE=`tput setaf 5`
NOCOLOR=`tput sgr0`

function yellow {
  echo -e -n "${YELLOW}$* $NOCOLOR\n"
}
function green {
  echo -e -n "${GREEN}$* $NOCOLOR\n"
}
function red {
  echo -e -n "${RED}$* $NOCOLOR\n"
}
function purple {
  echo -e -n "${PURPLE}$* $NOCOLOR\n"
}

function createFileList(){
  green "Creating list of files to process..."
  aws s3 ls s3://company-redis-dr/${dbName}/ > /tmp/${dbName}
  awk '{print $4}' /tmp/${dbName} > /tmp/${dbName}.txt
}

function cutDate(){
  somedate=$(echo $line | awk -F- '{print $1}' | sed -e 's/bk//g')
  if [[ ${#somedate} -ne 8 ]]; then
    echo "Date not formatted properly!"
    exit 1
  fi
}

function splitToArrays(){
  num=$(wc -l < /tmp/${dbName}.txt | sed -e 's/^    //g')
  let splitnum=$num / 1000
  for i in $(seq 1 $splitnum); do
    while [[ $count -le 1000 ]]; do
      if [[ $dateDiff -gt 14 && $dateDiff -lt 90 ]]; then
        yellow "Date difference is between 14 and 90 days!"
        if [[ ! $line =~ ^bk${somedate}-${chosenBackupHour}.* ]]; then
          red "deleting file $line"
          #red "COMMAND: aws s3 rm s3://${bucketName}/${dbName}/${line}"
          arr${i}+=("key" "${line}" )
          let "count++"
        else
          green "LINE $line contains ${chosenBackupHour} so not deleting!"
        fi
      fi
    done
    echo ${arr${i}[@]}
  done
}

function findFilesToDelete(){
  if [[ $dateDiff -gt 14 && $dateDiff -lt 90 ]]; then
    yellow "Date difference is between 14 and 90 days!"
    if [[ ! $line =~ ^bk${somedate}-${chosenBackupHour}.* ]]; then
      red "deleting file $line"
      red "COMMAND: aws s3 rm s3://${bucketName}/${dbName}/${line}"
    else
      green "LINE $line contains ${chosenBackupHour} so not deleting!"
    fi
  fi
}

function dateDiff(){
  bkYear=$(echo ${somedate:0:4})
  bkMonth=$(echo ${somedate:4:2})
  bkDay=$(echo ${somedate:8-2})
  bkpDate=${bkYear}-${bkMonth}-${bkDay}
  yellow ---------------------------------------------------------------------------------
  purple "Backup filename: $line"
  purple "Today Date: $todayDate"
  purple "Backup Date: $bkpDate"
  dateDiff=$(ddiff $todayDate $bkpDate | tr -d '-')
  purple "DateDiff: $dateDiff"
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

while getopts "n:" opt; do
  case $opt in
    n)
    dbName=${OPTARG}
    ;;
    *)
    usage
    exit 1
    ;;
  esac
done

createFileList
#for line in $(tac /tmp/${dbName}.txt ); do
for line in $(tac /tmp/rofbbb ); do
  cutDate
  dateDiff
  findFilesToDelete
  #splitToArrays
done
rm -f /tmp/${dbName}.txt

