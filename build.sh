
cd /tmp

PUBLIC_KEY_NAME=$1
LATEST_NODE_VERSION=$(./nave.sh stable)


# 0. Prerequisites

./nave.sh usemain $LATEST_NODE_VERSION

which mocha || npm install -g mocha
which git || apt-get install git-core
which ruby || apt-get install ruby1.9.1
which foreman || gem install foreman

which phantomjs || {
  apt-get install build-essential chrpath git-core libssl-dev libfontconfig1-dev
  git clone git://github.com/ariya/phantomjs.git
  cd phantomjs
  git checkout 1.6
  ./build.sh
  cd ..
}


# 1. gitolite

useradd git
mkdir "/home/git"
cp "$PUBLIC_KEY_NAME" "/home/git/$PUBLIC_KEY_NAME"
chown -R git:git "/home/git"

sudo -u git git clone "git://github.com/sitaramc/gitolite" "/home/git/gitolite"
sudo -u git "/home/git/gitolite/install" -ln
sudo -u git "/home/git/.bin/gitolite" setup -pk "/home/git/$PUBLIC_KEY_NAME"
