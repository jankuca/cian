#!/bin/bash

command="$1"


usage () {
  echo -e "Usage: \033[0;36m$0 \033[0;37m<command> [options]\033[0m"
  echo -e ""
  echo -e "Commands:"
  echo -e "  \033[0;36mcreate\033[0m                creates a new app"
  echo -e "  \033[0;36mreceive\033[0m               notifies cian about new commits"
  exit 1
}

help () {
  echo -e "Usage: \033[0;36m$0 $command \033[0;37m[options]\033[0m"
  echo -e

  case "$command" in

  create)
    echo -e "Options:"
    echo -e "  \033[0;36m--app \033[0;37m<app>\033[0m           app name"
    ;;

  receive)
    echo -e "Options:"
    echo -e "  \033[0;36m--app \033[0;37m<app>\033[0m           app name"
    echo -e "  \033[0;36m--branch \033[0;37m<branch>\033[0m     branch name"
    echo -e "  \033[0;36m--rev \033[0;37m<sha>\033[0m           revision SHA1 hash"
    ;;

  *)
    echo -e "\033[0;31mUnknown command:\033[0m $command"
    exit 1
  esac
  exit 1
}


# Command
if [ $# = 0 ]; then
  usage
fi

shift

# Options
if [ $# = 0 ]; then help; fi

arg_value () {
  if [ -z "$1" ] || [ "${1:0:2}" = "--" ]; then
    return 1
  fi

  echo "$1"
}

while [ $# -ne 0 ]; do
  case "$1" in
  '--help') help ;;

  '--app') app="$(arg_value "$2")" || help; shift ;;
  '--branch') branch="$(arg_value "$2")" || help; shift ;;
  '--rev') rev="$(arg_value "$2")" || help; shift ;;

  *) echo -e "\033[0;31mUnknown option:\033[0m $1\n"; help
  esac

  shift
done



align_col () {
  local i=${#1}
  while [[ $i -le 30 ]]; do
    echo -ne " "
    (( i++ ))
  done
}


_request () {
  align_col "connect to \"localhost:9002\""
  echo -ne "connect to \033[0;37m\"localhost:9002\"\033[0m : "
  exec 3<>/dev/tcp/localhost/9002 && echo -e "\033[0;32mok\033[0m" || {
    echo -e "\033[0;31merror\033[0m"
    return 1
  }

  align_col "send \"$1\""
  echo -ne "send \033[0;37m\"$1\"\033[0m : "
  echo -e "$1\n" >&3 && echo -e "\033[0;32mok\033[0m" || {
    echo -e "\033[0;31merror\033[0m"
    return 1
  }

  local line
  read line <&3

  local status=$(echo "$line" | cut -d " " -f 1)
  if [ "$status" = "" ]; then status="0"; fi

  align_col "status"
  echo -e "status : $status"

  case "$status" in
  200) return 0
  *) return 2
  esac
}


echo ""

case "$command" in

create)
  if [ -z "$app" ]; then help create; fi

  mkdir -p "/var/apps/$app" || {
    echo -e "\n\033[1;31mFailed to create the app directory\033[0m"
    exit 1
  }
  chown git:git "/var/apps/$app"
  echo -e "\n\033[0;32mThe app successfully created\033[0m"

  _request "UPDATE /apps/$app" 2> /dev/null || {
    echo -e "\n\033[1;31mFailed to notify the cian process\033[0m"
    exit 1
  };;

receive)
  if [ -z "$app" ] || [ -z "$branch" ] || [ -z "$rev" ]; then help receive; fi

  _request "RECEIVE /apps/$app/$branch/$rev" 2> /dev/null || {
    echo -e "\n\033[1;31mFailed to notify the cian process\033[0m"
    exit 1
  };;

esac


# foreman export upstart ~/init -a scrobbler_master -p 6000 -l /var/log/apps/scrobbler/master/ -u git
