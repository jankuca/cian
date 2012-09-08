
git submodule update --init --recursive
apt-get install curl


SOURCE_DIR=$(pwd)
INSTALL_DIR=/opt/cian

LATEST_NODE_VERSION=$(./vendor/nave/nave.sh stable)

PUBLIC_KEY_NAME="$1"
if [ -z "$PUBLIC_KEY_NAME" ]; then
  echo "No public key file specified"
  exit 1
fi
if [ ! -f "$PUBLIC_KEY_NAME" ]; then
  echo "\033[0;31mThe specified public key file does not exist.\033[0m"
  exit 1
fi


# 0. Prerequisites

node -v 2> /dev/null || { echo "\033[0;31mNode.js is not installed.\033[0m"; exit 1; }

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
  cd $SOURCE_DIR
}


# 1. gitolite

useradd git
mkdir /home/git
cp "$PUBLIC_KEY_NAME" "/home/git/$PUBLIC_KEY_NAME"
chown git:git "/home/git"
chown git:git "/home/git/$PUBLIC_KEY_NAME"

sudo -u git git clone git://github.com/sitaramc/gitolite /home/git/gitolite
sudo -u git /home/git/gitolite/install -ln
sudo -u git /home/git/.bin/gitolite setup -pk "/home/git/$PUBLIC_KEY_NAME"


# 2. cian

mkdir "$INSTALL_DIR"
cp "$SOURCE_DIR" "$INSTALL_DIR"
ln "$INSTALL_DIR/cian" /usr/local/bin/cian


# 3. git hooks

ln -s "$INSTALL_DIR/hooks/common/pre-receive" /home/git/.gitolite/hooks/common/pre-receive


# 4. init scripts

ln -s "$INSTALL_DIR/init/cian" /etc/init/cian

