#!/bin/bash
# This script runs through a given directory in an s3 redislabs backups bucket
# where Versioning is enabled. It finds all backups older than 14 days and
# earlier than 90 days, keeps backups of one hour per each day and deleting
# the rest of the backups of that day including all previous versions of each
# file and their Latest versions.
# The script matches the following naming convention:
# bk20190903-150002-2-CompanyDB-NEW-54_of_100-208-8684-8846.rdb.gz

todayDate=$(date +'%Y-%m-%d')
runTime=$(date +'%H:%M:%S')

function usage(){
  echo  "-----------------------------------------------------------------------"
  echo  "# Usage: ${basename}${0} -b bucket_name -t chosen_backup_time    #"
  echo  "# Available redis database bucket names:                #"
  echo    "# company-redis-dr                                   #"
  echo    "# company-redis-enterprise-backup                    #"
  echo  "# Chosen backup times: "
  echo    "# Any hour within 00 and 23 (2 digits)                  #"
  echo  "---------------------------------------------------------"
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

function scriptRequirements(){
  which ddiff &> /dev/null
  if [[ ! $? -eq 0 ]]; then
    echo "ddiff command not found, installing..."
    cd /tmp
    wget https://bitbucket.org/hroptatyr/dateutils/downloads/dateutils-0.4.6.tar.xz
    tar xvf dateutils-0.4.6.tar.xz
    cd dateutils-0.4.6
    ./configure
    make
    sudo cp src/ddiff /usr/bin/
    rm -rf /tmp/dateutils-0.4.6.tar.xz /tmp/dateutils-0.4.6
  fi
}

function createDbList(){
  echo "Creating list of databases in the bucket, this could take up to 15 minutes so be patient..."
  dbList=$(aws s3 ls s3://$bucketName | grep PRE | awk '{print $2}' | tr -d '\/' | sed -e '/^$/d')
}

function createFileList(){
  case $database in
    'RedisBackUps')
    echo "Processing files for database C45..."
    database='RedisBackUps'
    ;;
    'redisbackups')
    echo "Processing files for database C45..."
    database='RedisBackUps'
    ;;
    'tier-3')
    echo "Processing files for database ROF2..."
    database='tier-3'
    ;;
    *)
    echo "Processing files for database ${database}..."
    ;;
  esac
  aws s3 ls s3://${bucketName}/${database}/ > /tmp/${database}
  awk '{print $4}' /tmp/${database} > /tmp/${database}.txt
}

function cutDate(){
  somedate=$(echo $line | awk -F- '{print $1}' | sed -e 's/bk//g')
  if [[ ${#somedate} -ne 8 ]]; then
    echo "Date not formatted properly!"
    exit 1
  fi
}

function findFilesToDelete(){
  if [[ $dateDiff -gt 14 && $dateDiff -lt 90 ]]; then
    echo "Date difference is between 14 and 90 days!"
    if [[ ! $line =~ ^bk${somedate}-${chosenBackupHour}.* ]]; then
      echo "Deleting file $line..."
      aws s3 rm s3://${bucketName}/${database}/${line}
      lineDeleteMarkerVersionIds=$(aws s3api list-object-versions --bucket ${bucketName} --prefix ${database}/${line} --output json --query 'DeleteMarkers[].VersionId' | jq -r '.[]')
      echo "Deleting all versions of file ${line}"
      for delMarkerVerId in $(echo $lineDeleteMarkerVersionIds); do
        echo "Deleting DeleteMarker of file ${line} with VersionId ${delMarkerVerId}..."
        aws s3api delete-object --bucket ${bucketName} --key ${database}/${line} --version-id ${delMarkerVerId}
      done
      echo "Deleting Latest version of file ${line}..."
      latestVersion=$(aws s3api list-object-versions --bucket ${bucketName} --prefix ${database}/${line} --output json --query 'Versions[].VersionId' | jq -r '.[]')
      aws s3api delete-object --bucket ${bucketName} --key ${database}/${line} --version-id ${latestVersion}
    else
      echo "Filename $line contains selected ${chosenHour} so not deleting!"
    fi
  fi
}

function dateDiff(){
  bkYear=$(echo ${somedate:0:4})
  bkMonth=$(echo ${somedate:4:2})
  bkDay=$(echo ${somedate:8-2})
  bkpDate=${bkYear}-${bkMonth}-${bkDay}
  echo ---------------------------------------------------------------------------------
  case $database in
    'RedisBackUps')
    echo "Database name: C45"
    ;;
    'redisbackups')
    echo "Database name: C45"
    ;;
    'tier-3')
    echo "Database name: ROF2"
    ;;
    *)
    echo "Database name: ${database}"
    ;;
  esac
  echo "Selected backup hour: $(echo ${chosenHour} | sed 's/\(..\)/&:/g' | sed 's/:$//')"
  echo "Backup filename: $line"
  echo "Today Date: $todayDate"
  echo "Backup Date: $bkpDate"
  dateDiff=$(ddiff $todayDate $bkpDate | tr -d '-')
  echo "DateDiff: $dateDiff"
}

function cleanTraces(){
  rm -f /tmp/${database}.txt
  rm -f /tmp/${database}
}

if [[ $# -lt 4 ]]; then
  usage
  exit 1
fi

while getopts "b:t:" opt; do
  case $opt in
    b)
    bucketName=${OPTARG}
    ;;
    t)
    chosenBackupHour=${OPTARG}
    ;;
    *)
    usage
    exit 1
    ;;
  esac
done

echo "Script has started running at: ${runTime}"
scriptRequirements
createDbList
for database in $(echo $dbList |  tr "[:upper:]" "[:lower:]"); do
#for database in $(cat /Users/itaiganot/src/company/devops/scripts/222 |  tr "[:upper:]" "[:lower:]"); do
  if [[ $database = 'RedisBackUps' || $database = 'redisbackups' ]]; then
    chosenHour="${chosenBackupHour}0002"
  else
    chosenHour="${chosenBackupHour}0000"
  fi
  createFileList
  for line in $(tac /tmp/${database}.txt ); do
    cutDate
    dateDiff
    findFilesToDelete
  done
  cleanTraces
done
