#!/bin/bash
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

function usage(){
	yellow "${basename}${0} -n Max_Num -d Divider"
}

if [[ $# -lt 4 ]]; then
	red "Not enough arguments have been passed!"
	usage
	exit 1
else
	while getopts "n:d:" opt; do
		case $opt in
			n)number=${OPTARG}
			;;
			d)div=${OPTARG}
			;;
			*)usage
			;;
		esac
	done
	yellow "User passed the following arguments:"
	yellow "Max number: $number, Divider: $div"

	for num in $(seq 1 $number); do
		if [[ $num -eq $div ]] || (( $num % $div == 0 )) ; then
			green "Boom! ($num)"
		else
			echo $num
		fi
	done
fi
