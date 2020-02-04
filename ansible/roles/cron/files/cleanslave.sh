#!/bin/bash

<< ////
CLEAN JENKINS SLAVES - FREE UP DISK SPACE

The procedure steps:
	1. Clean all gradle logs
	2. Prune all docker images containers and volumes (CURRENTLY NOT IN USE)
	3. Purge all job folders in workspace that were modified more that 24 hours ago

	4. If still not enough space purge folders (within 0 - 24 hours)
		a. that are not currently in use
		b. that are not from exclude list
	5. If still not enough space purge the rest of folders - start removing folders one by one from exclude list according to priority (NOT IN USE)
////

DRYRUN=false	# true = actual 'remove step' will be skipped (true/false)

LOG_PATH=/root/jenkins/workspace/autoclean.log
J_WORKSPACE=/root/jenkins/workspace

# Percentage threshold for disk space in USE ( default 80% )
SPACE_THRESHOLD=30

RC="tss-R[0-9][0-9]-[0-9]"
RC_FINAL="${RC}.*final"

# Exclude list by priority
EXCLUDED_JOBS=(
	"tss-trunk"
	"tss-trunk-Full-IT-Tests"
)


# Purge all docker containers images and volumes
docker_clean() {

	# Implement a condition to verify cleaning images/containers not being in use
	which docker
	if [ $? -eq 0 ]; then
		docker container prune -f
		docker image prune -f
		docker volume prune -f
	fi
}

# Return total percentage of disk space USE
check_diskspace() {

	local _size=`df -h | grep "% /$" | sed 's/.*G\ //g' | sed 's/%.*//g'`
	echo "> Use disk space ="$_size >>${LOG_PATH}
	echo $_size
}

remove_entity() {

	local _entity=$1

	# if WORKSPACE folder received - dont remove workspace folder
	[ "${_entity}" == "${J_WORKSPACE}" ] || [ "$_entity" == "${J_WORKSPACE}/" ] || [ `echo "$_entity" | grep "autoclean.log"` ] && return

	if [ "${DRYRUN}" != "false" ]; then
		echo ">> !! DRYRUN ENABLED - Skipping actual remove"
		echo ">> !! DRYRUN ENABLED - Skipping actual remove" >>${LOG_PATH}
		return
	fi

	echo rm -rf -- "${_entity}*"
	rm -rf -- "${_entity}"*
}

# Remove all log files for gradle
clean_gradle_logs() {

	_dir=`pwd` && cd /root/.gradle/daemon/
	find /root/.gradle/daemon/ -name '*.log' -exec rm -f -- {} \;
	cd $_dir
	# cd -
}

# Check if current specific job is in Excluded List
is_job_excluded() {

	local _testFoldeName=$1

	#find . -maxdepth 1 -name "${_testFoldeName}$" | grep -q "." # We use grep to workaround - to return non-zero code in case of nothing found

	for _excludedJob in "${EXCLUDED_JOBS[@]}"
	do
		echo "${_testFoldeName}" | grep "${_excludedJob}" | grep -v patch && echo EXCLUDED && return
		#echo "${_testFoldeName}" | grep "${RC_FINAL}" | grep -v patch && echo EXCLUDED && return
		#echo "${_testFoldeName}" | grep "${RC}" | grep -v patch && echo EXCLUDED && return
	done
}

# Check if current specific job is in use by Jenkins job
is_folder_in_use() {

	local _folder=$1

	fuser ${_folder} && return || sleep 3	# Check if candiate folder is currently in use
	fuser ${_folder} && return
}

# Remove all recent (between 0 - 48 hours) jobs that are NOT in USE and NOT from EXLCLUDED LIST
remove_recent_jobs() {

	for _jobDir in ${J_WORKSPACE}/*
	do
		[ `echo "${_jobDir}" | grep @tmp` ] && continue
		is_job_excluded "${_jobDir}" && continue
		is_folder_in_use "${_jobDir}" && continue

		remove_entity "${_jobDir}"
	done
}

# Delete folders that were modified more than 48 hours ago - (for configuring "24 hours ago" use 'mtime +0')
remove_old_jobs() {

	local days=$1
	for _job in $(find ${J_WORKSPACE} -maxdepth 1 -mtime +${days})
	do
		[ `echo "${_job}" | grep @tmp` ] && continue	# We do not remove tmp folders (they will be removed along with regular branch folders)
		is_job_excluded "${_job}" && continue
		is_folder_in_use "${_job}" && continue

		remove_entity "${_job}"
	done
}


main() {

	while test $# -gt 0; do
		case "$1" in
			-dryrun)
				shift
				DRYRUN=$1
				shift
				;;
			*)
				echo "$1 is not a recognized flag! - Usage: cleanslave.sh -dryrun false/true"
				shift
				;;
		esac
	done

	echo ===================================
	echo DRYRUN=$DRYRUN
	echo ===================================

	echo DRYRUN=$DRYRUN >>${LOG_PATH}

	[ $(check_diskspace) -lt $SPACE_THRESHOLD ] && exit 0
	remove_old_jobs 0
	[ $(check_diskspace) -lt $SPACE_THRESHOLD ] && exit 0
	remove_recent_jobs

	# [ $(check_diskspace) -lt $SPACE_THRESHOLD ] && exit 0
	# remove_priority_jobs
}

# S * T * A * R * T
echo $(date) Clean slave folder >>${LOG_PATH}

clean_gradle_logs

cd ${J_WORKSPACE}
main $*

echo "-----------------" >>${LOG_PATH}
