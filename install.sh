#!/bin/bash

usage () {
  echo -e "Usage: \033[0;36m$0 \033[0;37m[options]\033[0m"
  echo -e ""
  echo -e "Options:"
  echo -e "  \033[0;36m--help \033[0;37m\033[0m               print this message"
  echo -e "  \033[0;36m--pk \033[0;37m<path>\033[0m           public key file to use"
  echo -e ""
  echo -e "  \033[0;36m--dir \033[0;37mpath\033[0m            where to store apps; default: /var/apps"
  echo -e "  \033[0;36m--gituser \033[0;37musername\033[0m    git user username; default: git"
  echo -e "  \033[0;36m--phantomjs \033[0;37m\033[0m          install PhantomJS"
  exit 0
}


# Options

if [ $# = 0 ]; then usage; fi

dir=/var/apps
gituser=git

arg_value () {
  if [ -z "$1" ] || [ "${1:0:2}" = "--" ]; then
    return 1
  fi

  echo "$1"
}

while [ $# -ne 0 ]; do
  case "$1" in
  '--help') usage ;;

  '--pk') public_key="$(arg_value "$2")" || usage; shift ;;
  '--dir') dir="$(arg_value "$2")" || usage; shift ;;
  '--gituser') gituser="$(arg_value "$2")" || usage; shift ;;
  '--phantomjs') install_phantomjs=1 ;;

  *) echo "Unknown option $1"; exit 1
  esac

  shift
done


align_col () {
  local i=${#1}
  while [[ $i -le 20 ]]; do
    echo -ne " "
    (( i++ ))
  done
}

check () {
  local name="$1"

  align_col "$name"
  echo -ne "\033[0;36m$name\033[0m"
  echo -ne " : \033[0;32m"
  which "$name" && { echo -ne "\033[0m"; return 0; } || { echo -ne "\033[0m"; return 1; }
}

install () {
  local name="$1"
  local install_cmd=""
  shift; shift
  while [ $# -gt 0 ]; do
    if [ -z "$install_cmd" ]; then
      install_cmd="$1"
    else
      install_cmd="$install_cmd $1"
    fi
    shift
  done

  check "$name" || {
    echo -e "\033[0;33mnot found -> install\033[0m"

    $install_cmd
    check "$name" || {
      echo -e "\033[0;31mnot installed\033[0m"
      return 1
    }
  }
}


# 1. prerequisites

echo ""

SOURCE_DIR=$(pwd)
INSTALL_DIR=/etc/cian

install curl : apt-get install curl || exit 1
install git : apt-get install git-core || exit 1
install ruby : apt-get install ruby1.9.1 || exit 1
install foreman : gem install foreman || exit 1

git submodule update --init --recursive || exit 1

echo -e "$(align_col nave)\033[0;36m./nave.sh\033[0m : \033[0;32m./vendor/nave/nave.sh\033[0m"
LATEST_NODE_VERSION=$(./vendor/nave/nave.sh stable)
install node : ./vendor/nave/nave.sh usemain $LATEST_NODE_VERSION || exit 1

echo -n "node -v : "
if [ "$(node -v)" = "v$LATEST_NODE_VERSION" ]; then
  echo -ne "\033[0;32m"
  echo -n $(node -v)
  echo -e "\033[0m"
else
  echo -ne "\033[0;33m"
  echo -n $(node -v)
  echo -e " -> v$LATEST_NODE_VERSION (latest stable)\033[0m"
  ./vendor/nave/nave.sh usemain $LATEST_NODE_VERSION || {
    echo -e "\033[0;31mFailed to upgrade node\033[0m"
    exit 1
  }
fi

install mocha : npm install -g mocha

if [ $install_phantomjs ]; then
  check phantomjs || {
    apt-get install build-essential chrpath git-core libssl-dev libfontconfig1-dev
    cd /tmp
    git clone git://github.com/ariya/phantomjs.git
    cd phantomjs
    git checkout 1.6
    ./build.sh
    cd $SOURCE_DIR
    check phantomjs || {
      echo -e "\033[0;31mnot installed\033[0m"
      exit 1
    }
  }
fi

exit


# 2. user info

if [ -z "$public_key" ]; then
  echo "No public key file specified"
  exit 1
fi
if [ ! -f "$public_key" ]; then
  echo "\033[0;31mThe specified public key file does not exist.\033[0m"
  exit 1
fi

admin_username=$(basename "$public_key")
admin_username="${public_key%\.*}"
echo -n "Admin username: [$admin_username] "
read admin_username
if [ -z "$admin_username" ]; then
  admin_username="${PUBLIC_KEY_NAME%\.*}"
fi

echo -n "Admin password: "
read -s admin_password
if [ -z "$admin_password" ]; then
  echo "\033[0;31mThe password cannot be empty.\033[0m"
  exit 1
fi

echo -n "Repeat: "
read -s admin_password_confirm
if [ "$admin_password" != "$admin_password_confirm" ]; then
  echo "\033[0;31mPasswords do not match.\033[0m"
  exit 1
fi


# 3. gitolite

useradd "$gituser"
mkdir -p "/home/$gituser"
cp "$public_key" "/home/$gituser"
chown "$gituser:$gituser" "/home/$gituser"
chown "$gituser:$gituser" "/home/$gituser/$(basename $public_key)"

sudo -u "$gituser" git clone git://github.com/sitaramc/gitolite "/home/$gituser/gitolite"
sudo -u "$gituser" "/home/$gituser/gitolite/install" -ln
sudo -u "$gituser" "/home/$gituser/.bin/gitolite" setup -pk "/home/$gituser/$(basename $public_key)"


# 4. cian

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR" || {
  echo -e "\n\033[1;31mFailed to create $INSTALL_DIR\033[0m"
  exit 1
}
cp "$SOURCE_DIR" "$INSTALL_DIR"
ln "$INSTALL_DIR/cian.sh" /usr/local/bin/cian || {
  echo -e "\n\033[1;31mFailed to add the cian executable to /usr/local/bin\033[0m"
  exit 1
}

{
  echo "config:"
  echo "  admin:"
  echo "    pk: $public_key"
  echo "    username: $admin_username"
  echo "  dir: $dir"
  echo "  gituser: $gituser"
} >> "$INSTALL_DIR/config.yml"

chown -R "$gituser:$gituser" "$INSTALL_DIR"


# 5. git hooks

ln -s "$INSTALL_DIR/hooks/common/pre-receive" "/home/$gituser/.gitolite/hooks/common/pre-receive"


# 6. init scripts

ln -s "$INSTALL_DIR/init/cian.conf" /etc/init/cian.conf


# 7. gitolite-admin repository

git clone "git@localhost:gitolite-admin.git" "$INSTALL_DIR/gitolite-admin"
cian useradd "$admin_username" --password "$admin_password"
