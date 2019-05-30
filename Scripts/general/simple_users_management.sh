#!/bin/bash
# This script creates or deletes a local linux user and is able to add the user
# to sudoers.
# Script by Itai Ganot, 2019. mailto: lel@lel.bz
function usage(){
  echo "######################== Company User Creation Script ==######################"
  echo "This script adds and configures a new local linux user                        "
  echo "-u                   Username                                                 "
  echo "-f                   Full Name                                                "
  echo "-d  [USERNAME]                                                                "
  echo "Optional:                                                                     "
  echo "-s          Give created user sudo access                                     "
  echo "Examples:                                                                     "
  echo "Create user:                                                                  "
  echo "$basename$0 -u USERNAME                                                       "
  echo "Create user with Full Name:                                                   "
  echo "$basename$0 -u USERNAME -f \"Jon Doe\"                                        "
  echo "Create user with sudo access:                                                 "
  echo "$basename$0 -u USERNAME -s                                                    "
  echo "Delete user \(if the user is a sudoer, it will also be delete from sudoers\): "
  echo "$basename$0 -d USERNAME                                                       "
  echo "##############################################################################"
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

if [[ $(id -u) -ne 0 ]]; then
  echo "Please run as root! exiting!"
  exit 1
fi

sudo="false"
fullname=""
deleteuser=""
while getopts ":u:f:sd:" opt; do
  case ${opt} in
    u)
      username=$OPTARG
    ;;
    f)
      fullname=$OPTARG
    ;;
    s)
      sudo="true"
    ;;
    d)
      deleteuser=$OPTARG
    ;;
    *)
      usage
      exit 1
    ;;
  esac
done

userpassword=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12 ; echo '')

if [[ ! -z $deleteuser ]]; then
  userdel -rf $deleteuser
  if [[ $(grep -q "^${deleteuser}" /etc/sudoers) -eq 0 ]]; then
    sed -i "/^$deleteuser.*/d" /etc/sudoers
    mark "User $deleteuser deleted from instance and sudoers"
    exit 0
  else
    mark "User $deleteuser deleted from instance"
  fi
else
  id $username &>/dev/null
  if [[ $? -ne "0" ]]; then
    useradd -m $username
    mark "User \"$username\" with password \"$userpassword\" created successfully!"
  else
    mark "User $username already exists!"
    id $username
    exit 1
  fi
  if [[ ! -z $fullname ]]; then
    chfn -f "$fullname" $username &>/dev/null
  fi

  echo ${username}:${userpassword} | /usr/sbin/chpasswd
  if [[ $sudo = 'true' ]]; then
    grep $username /etc/sudoers
    if [[ $? -ne "0" ]]; then
      echo "$username    ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
      mark "User added to suoders!"
    fi
  fi
fi
