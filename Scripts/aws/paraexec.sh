# This script accepts a server list file and executes given command paralleli on all the servers in the list.
#!/bin/bash

function usage {
	echo "Usage: $(basename $0) [OPTIONS] [LIST(s)] COMMANDS"
	echo ""
	echo "Options:"
	echo "   -user     :     Run commands as user user"
	echo ""
}

if [ -z "$1" ] || [ -z "$2" ] ; then
	usage
	exit 1
fi

TIMEOUT=5
SESSIONS=8
LISTFILE=/tmp/paraexeclist.lst

OPTION_USER="false"

# Process arguments
for a in "$@" ; do
	if [[ $a == -* ]] ; then
		case $(tr -d "-" <<< "$a") in
			"clean") OPTION_CLEAN="true";;
			"color") OPTION_NOCOLOR="true";;
			"user") OPTION_USER="true";;
			*) echo "ERROR: Invalid argument $a"
			   exit 1;;
		esac
		shift
	else
		break
	fi
done

LIST=()
for f in "$@" ; do
	if [ -f "$f" ] && [[ $f == *.lst* ]] || [[ $f == *.list* ]]; then
		LIST+=($(cat -v $f))
		shift
	else	
		break
	fi
done

if [ ${#LIST[@]} -eq 0 ] ; then
	echo "!!! paraexec error"
	echo "    No lists provided or lists are empty"
	echo "    REMEMBER: list files must have .lst or .list suffix"
	echo "    passed arguments: $@"
	exit 1
elif [ ${#@} -eq 0 ] ; then
	echo "ERROR: No commands given"
	echo "passed argument: $@"
	exit 1
fi

if ! printf "%s\n" "${LIST[@]}" > $LISTFILE ; then
	echo "!!! paraexec error"
	echo "    Can't write to $LISTFILE"
	exit 1
fi

COMMANDS=""

#Run commands as user?
if [ "$OPTION_USER" = "true" ] ; then
	COMMANDS="su - user -c '$@'"
else
	COMMANDS="$@"
fi

#time pssh -P -i -p $SESSIONS -O ConnectTimeout=$TIMEOUT -h $LISTFILE "$COMMANDS"
/usr/local/bin/pssh -l user -i -p $SESSIONS -t 100000000 -x "-oStrictHostKeyChecking=no  -i /home/jenkins/.ssh/user.pem" -O ConnectTimeout=$TIMEOUT -h $LISTFILE "$COMMANDS"
