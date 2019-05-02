#!/bin/bash
# Script by Itai Ganot, 2019. mailto: lel@lel.bz
function usage(){
  echo "#########== Company SFTP User Configuration ==#########"
  echo "This script adds and configures a new sftp user           "
  echo "-c          create                                        "
  echo "-d          delete                                        "
  echo "-w          create a writable directory in the user's home"
  echo "Example:                                                  "
  echo "$basename$0 -c Username                                   "
  echo "##########################################################"
}

GREEN=$(tput setaf 2)
NOCOLOR=$(tput sgr0)

function mark {
  echo -e -n "$GREEN $* $NOCOLOR\n"
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

writeable="false"
while getopts "c:d:w" opt; do
  case ${opt} in
    c)
      username=$OPTARG
      action="create"
    ;;
    d)
      username=$OPTARG
      action="delete"
    ;;
    w)
      writable="true"
    ;;
    *)
      usage
      exit 1
    ;;
  esac
done

ftphome="/packages"

if [[ $action = "create" ]]; then
  userpassword=$(date | md5sum | awk '{print $1}' | cut -c1-10)
  useradd -m -b ${ftphome} -g sftp -s /bin/false ${username}
  if [[ $? -ne "0" ]]; then
    echo "User creation failed!"
    exit 1
  fi
  echo ${username}:${userpassword} | /usr/sbin/chpasswd
  chown -R root:root ${ftphome}/${username}/
  chmod go-w ${ftphome}/${username}
  mark "User ${username} with password ${userpassword} created successfully!"
  if [[ $writable == "true" ]]; then
    mkdir ${ftphome}/${username}/writable
    chown ${username}:sftp ${ftphome}/${username}/writable
    chmod ug+rwX ${ftphome}/${username}/writable
    mark "Writable directory created for user ${username} in path: ${ftphome}/${username}/writable"
  fi
  mark "After copying files to the users home folder ${ftphome}/${username}, run:"
  mark "chown ${username}:sftp ${ftphome}/${username}/file"
  exit 0
elif [[ $action = "delete" ]]; then
  pkill -u ${username}
  userdel -rf ${username}
  rm -rf ${ftphome}/${username}
fi
