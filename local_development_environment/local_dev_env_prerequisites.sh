#!/bin/bash
# Versions
nvmVersion='8.12.0'
rubyVersion='2.4.2'

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
NOCOLOR=$(tput sgr0)

function red() {
	echo -e -n "$RED $* $NOCOLOR\n"
}

function green() {
	echo -e -n "$GREEN $* $NOCOLOR\n"
}

function yellow() {
	echo -e -n "$YELLOW $* $NOCOLOR\n"
}

if [[ $1 == "uninstall" ]]; then
	sudo chown -R $(whoami) /usr/local
	sed -i.bak '/.*rvm.*/d' ~/.bashrc ~/.bash_profile ~/.zshrc
	sed -i.bak '/.*nvm.*/d' ~/.bashrc ~/.bash_profile ~/.zshrc
	docker ps -a | awk 'NR>1 {print $1}' | xargs docker rm -f
	docker images | awk 'NR>1 {print $1}' | xargs docker rmi -f
	curl -ksO https://gist.githubusercontent.com/nicerobot/2697848/raw/uninstall-node.sh
	chmod +x ./uninstall-node.sh
	sudo ./uninstall-node.sh
	brew uninstall ruby automake gnupg node readline
	brew cleanup
	rm uninstall-node.sh
	rm -rf ~/.nvm ~/miniconda3 ~/.rvm
	exit 0
fi

### Check if docker is installed
mdfind "kMDItemKind == 'Application'" | grep -qi docker
if [[ $? -eq "0" ]]; then
	green "Nice! Docker is already installed!"
	green "Starting docker daemon"
	open --background -a Docker
else
	red "Docker desktop is not installed! please download from: https://hub.docker.com/editions/community/docker-ce-desktop-mac and re-run the script!"
	exit 1
fi

if [[ ! -f ~/.npmrc ]]; then
	red ".npmrc file not found in user's home! pleae configure .npmrc before continuing!"
	exit 1
fi

sudo chown -R "$(whoami)":admin /usr/local
chmod u+w /usr/local/var/log
#set -o verbose
### Tools setup
which -s brew
if [[ $? -eq "0" ]]; then
	echo "Nice! Homebrew is already installed!"
else
	echo "Homebrew is not installed! Please install manually and rerun this script!"
	echo "Installation command: /usr/bin/ruby -e \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)\""
  exit 1
fi
brew cleanup
which -s curl || brew install curl
which -s git  || brew install git
which -s npm  || brew install npm
which -s wget  || brew install wget
brew install python3 python-pip yamllint
brew list gnupg | grep -q gnupg || brew install gnupg
brew install redis
echo "Fixing system locale"
if [[ -f ~/.zshrc ]]; then
  yellow "Installing some commands to your ~/.zshrc file"
  echo "export LC_ALL=en_US.UTF-8" >> ~/.zshrc
  cat <<EOF >> ~/.zshrc
alias dcd='docker-compose down && docker system prune -f'
alias dcu='docker-compose down && docker system prune -f && docker-compose up -d --build'

function ddac(){
# Docker - delete all containers
  docker ps -a | awk 'NR>1 {print $1}' | xargs docker rm -f
}

function ddai(){
# Docker - delete all images
  docker images | awk 'NR>1 {print $3}' | xargs doker rmi -f
}

function dlsof(){
# Docker - display all ports exposed by docker container
  lsof -Pnl +M -i -cmd | grep -E "LISTEN|TCP"   | grep "com\.dock"
}
EOF
  source ~/.zshrc
else
  yellow "Installing some commands to your ~/.bashrc file"
  echo "export LANG=en_US.UTF-8" | tee -a ~/.bashrc ~/.bash_profile
  cat <<EOF >> ~/.bashrc
alias dcd='docker-compose down && docker system prune -f'
alias dcu='docker-compose down && docker system prune -f && docker-compose up -d --build'

function ddac(){
# Docker - delete all containers
  docker ps -a | awk 'NR>1 {print $1}' | xargs docker rm -f
}

function ddai(){
# Docker - delete all images
  docker images | awk 'NR>1 {print $3}' | xargs docker rmi -f
}

function dlsof(){
# Docker - display all ports exposed by docker container
  lsof -Pnl +M -i -cmd | grep -E "LISTEN|TCP"   | grep "com\.dock"
}
EOF
  source ~/.bashrc
fi
### Configure git global options
git config --global core.sshCommand 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
### RVM installation
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
curl -sSL https://rvm.io/mpapis.asc | gpg --import -
curl -sSL https://rvm.io/pkuczynski.asc | gpg --import -
\curl -sSL https://get.rvm.io | bash -s stable --ruby
source $HOME/.rvm/scripts/rvm
rvm install ruby-${rubyVersion}
rvm use ruby-${rubyVersion} --default
### NVM installation
curl -so- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash
source $HOME/.nvm/nvm.sh
nvm install ${nvmVersion}
nvm use ${nvmVersion}
### Installs docker-compose
pip install -U docker-compose
stat /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose
### Installation of linter
npm install --unsafe-perm -g eslint
### AWS-CLI installation
yellow "AWS-CLI tools are going to be installed/updated, please choose if you would like to configure AWS credentials"
read -r -p "Would you like to configure AWS-CLI now? [y/n] " answer
cd /tmp
curl -s "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
unzip awscli-bundle.zip
sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
rm -f /tmp/awscli-bundle.zip
if [[ $answer == [yY] ]]; then
	aws configure
else
	red "AWS (cli) configuration is required in order to run gameserver properly!"
fi

echo "Finished configuring local development environment prerequisites!"
