#!/bin/bash
# Script by Itai Ganot 2019, lel@lel.bz
function usage(){
  echo "##########== Company SFTP ==################"
  echo "This script adds and configures a new sftp user"
  echo "$basename$0 -c [ACTION] Username"
  echo "Available actions:"
  echo "create, delete"
  echo "###############################################"
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

while getopts "c:d:" opt; do
  case ${opt} in
    c)
      username=$OPTARG
      action="create"
    ;;
    d)
      username=$OPTARG
      action="delete"
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
  mark "After copying files to the users home folder ${ftphome}/${username}, run:"
  mark "chown ${username}:sftp file/s"
  exit 0
elif [[ $action = "delete" ]]; then
  pkill -u ${username}
  userdel -rf ${username}
  rm -rf ${ftphome}/${username}
fi
