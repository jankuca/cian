
CIAN_DIR=$(pwd)

PUBLIC_KEY_NAME="$1"
LATEST_NODE_VERSION=$(./vendor/nave/nave.sh stable)

if [ -z "$PUBLIC_KEY_NAME" ]; then
  echo "No public key file specified"
  exit 1
fi
if [ ! -f "$PUBLIC_KEY_NAME" ]; then
  echo "The specified public key file does not exist."
  exit 1
fi


# 0. Prerequisites

which node || (echo "Node.js is not installed."; exit 1)
which npm || (echo "NPM is not installed."; exit 1)

./vendor/nave/nave.sh usemain $LATEST_NODE_VERSION

which mocha || npm install -g mocha
which git || apt-get install git-core
which ruby || apt-get install ruby1.9.1
which foreman || gem install foreman

which phantomjs || {
  apt-get install build-essential chrpath git-core libssl-dev libfontconfig1-dev
  cd /tmp
  git clone git://github.com/ariya/phantomjs.git
  cd phantomjs
  git checkout 1.6
  ./build.sh
  cd $CIAN_DIR
}


# 1. gitolite

useradd git
mkdir /home/git
cp "$PUBLIC_KEY_NAME" "/home/git/$PUBLIC_KEY_NAME"
chown -R git:git /home/git

sudo -u git git clone git://github.com/sitaramc/gitolite /home/git/gitolite
sudo -u git /home/git/gitolite/install -ln
sudo -u git /home/git/.bin/gitolite setup -pk "/home/git/$PUBLIC_KEY_NAME"


# 2. pre-receive git hook

cp "$CIAN_DIR/hooks/common/pre-receive" /home/git/.gitolite/hooks/common/pre-receive
