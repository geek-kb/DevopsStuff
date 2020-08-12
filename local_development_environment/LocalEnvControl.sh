#!/bin/bash
# This script manages a local development environment on your Mac laptop.
# Find the full information about this script in the README.md file in its github repo:
# https://github.com/Company/local-development-environment
# This script has been tested on MacOSX only.
# Script by Itai Ganot 2019

# Editable Variables
defaultBranch='feature/local_development_env'
msList='leaderboard tournaments tagging scheduler scheduler-notifications advanced-group-queue test-profile client-error'

# Do not edit any lines below this line.
# Variables
scriptPath=$(cd "$(dirname "$0")"; pwd)
dateTime=$(date +'%d-%m-%y_%T' | tr ":" "-")
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
NOCOLOR=$(tput sgr0)

# Functions and input verification
function red() {
	echo -e -n "${RED}$* ${NOCOLOR}\n"
}

function green() {
	echo -e -n "${GREEN}$* ${NOCOLOR}\n"
}

function yellow() {
	echo -e -n "${YELLOW}$* ${NOCOLOR}\n"
}

function usage() {
  yellow "###### This tool expects the following arguments:  ######"
  yellow "Mandatory aruguments:"
  yellow "-r    Repository name without the \"microservice-\" prefix. "
  yellow "      also accepts lists of microservices divided by commas."
  yellow "Optional arguments:"
  yellow "-t    Tag of your docker images."
  yellow "      If no tag is manually supplied, the currently checked out branch of each microservice is selected as the tag."
  yellow "-b    Allows passing a specific branch for the gameserver repo, if not passed then the default branch is used."
  yellow "Or:                                                           "
  yellow "-D    Downs all the containers and cleans docker system cache "
  yellow ""
  yellow "Usage: ${0} -r microservice_name [-t tag]"
  yellow "Examples: "
  yellow "./LocalEnvControl.sh -r all"
  yellow "./LocalEnvControl.sh -r leaderboard,tournaments,tagging,scheduler,test-profile,client-error,advanced-group-queue,scheduler-notifications"
  yellow "./LocalEnvControl.sh -r advanced-group-queue -t myTag"
  yellow "./LocalEnvControl.sh -r advanced-group-queue,leaderboard"
	yellow "./LocalEnvControl.sh -r all -b develop"
	yellow "./LocalEnvControl.sh -D"
  yellow ""
}

if [[ ! -f "${scriptPath}/docker-compose.yml" ]]; then
  red "docker-compose.yml file is expected to reside in the same directory as this script!"
  exit 1
fi

while getopts "r:t:Db:" opt; do
  case $opt in
    r)repo=${OPTARG}
      ;;
    t)tag=${OPTARG}
      ;;
    D)down='true'
      ;;
    b)gameServerBranch=${OPTARG}
      ;;
    *)usage
      exit 1
      ;;
  esac
done

if [[ $down = 'true' ]]; then
  docker-compose down
  docker system prune -f
	ps -ef | grep npm | grep -v grep | awk '{print $2}' | xargs kill -9
	ps -ef | grep "node app.js" | grep -v grep | awk '{print $2}' | xargs kill -9
  exit 0
fi

if [[ -z ${gameServerBranch} ]]; then
  gameServerBranch="feature/local_dev_env_new_environment"
fi

if [[ -z ${repo} ]]; then
  usage
  exit 1
fi

if [[ ${repo} =~ ^microservice-* ]]; then
	usage
	red "Remove the \"microservice-\" prefix!"
	exit 1
fi

function createBins(){
if [[ ! -f /usr/local/bin/kgs ]]; then
	cat <<EOF >> /tmp/kgs
#!/bin/bash
gspid=\$(ps -ef | grep "node app\.js" | grep -v grep | awk '{print \$2}' | xargs)
  for procid in \${gspid}; do
    echo \${procid} | grep -q "^[0-9]*\$"
    if [[ \$? -eq 0 ]]; then
      echo "Going to kill gameserver process \${procid}"
      kill -9 \${procid}
    else
      echo "No Gameserver running processes were found!"
    fi
  done
EOF
chmod u+x /tmp/kgs
mv /tmp/kgs /usr/local/bin/
fi

if [[ ! -f /usr/local/bin/sgs ]]; then
	cat <<EOF >> /tmp/sgs
#!/bin/bash
dateTime=\$(date +'%d-%m-%y_%T' | tr ":" "-")
gsdefbranch="feature/local_dev_env_new_environment"
function usage(){
	echo "This script can accept a branch argument"
	echo "Example:"
	echo ".\${0} -b branchName"
}
while getopts "b:" opt; do
  case \${opt} in
    b)
      branch=\${OPTARG}
    ;;
    *)
      usage
      exit 1
    ;;
  esac
done
cd ${scriptPath}/local_env/gameserver
if [[ -z \${branch} ]]; then
	git checkout \${gsdefbranch}
  nohup npm run start:local > gameserver_\${dateTime}.log &
  echo "Log can be found in ${scriptPath}/local_env/gameserver/gameserver_\${dateTime}.log"
else
  git checkout \${branch}
  nohup npm run start:local > gameserver_\${dateTime}.log &
  echo "Log can be found in ${scriptPath}/local_env/gameserver/gameserver_\${dateTime}.log"
fi
EOF
chmod u+x /tmp/sgs
mv /tmp/sgs /usr/local/bin/
fi
}

function yamlLint(){
	which -s yamllint &>/dev/null
	if [[ $? -eq 0 ]]; then
		if [[ ! -f yamllint-conf ]]; then
		cat <<EOF >> yamllint-conf
extends: default

rules:
  key-duplicates: disable
EOF
		fi
		yamllint -d yamllint-conf --format parsable docker-compose.yml
		if [[ $? -ne 0 ]]; then
			red "Please fix errors in docker-compose.yml file and re-run"
			exit 1
		fi
	else
		echo "YamlLint is not installed, installing it..."
    brew install yamllint
		cat <<EOF >> yamllint-conf
extends: default

rules:
	key-duplicates: disable
EOF
		yamllint -d yamllint-conf --format parsable docker-compose.yml
		if [[ $? -ne 0 ]]; then
			red "Please fix errors in docker-compose.yml file and re-run"
			exit 1
		fi
	fi
}

function repoVerification(){
	if [[ ! -d "${scriptPath}/local_env/microservice-tagging" || ! -d "${scriptPath}/local_env/gameserver" ]]; then
		cd ${scriptPath}/local_env
		for dir in ${msList}; do
			git clone git@github.com:Company/microservice-${dir}.git
			if [[ $? -ne 0 ]]; then
				red "User lacks proper permissions to clone repo microservice-${dir}!"
				red "This is a prerequisite so please fix and rerun the script"
				exit 1
			fi
			cd microservice-${dir} && git checkout ${defaultBranch}
			cd ../
		done
		git clone git@github.com:Company/gameserver.git
	fi
}

function startGameserver(){
	# Check if gameserver is already running
	ps -ef | grep -v grep | grep -q "node app\.js"
	if [[ $? -eq 0 ]]; then
		read -r -p "gameserver is already running, shall I restart it? [y/n] " restartans
		if [[ ${restartans} = [Yy] ]]; then
			ps -ef | grep "node app\.js" | grep -v grep | awk '{print $2}' | xargs kill -9
			yellow "Waiting for gameserver to go down..."
			sleep 10
			cd ${scriptPath}/local_env/gameserver
			rm -f npm-shrinkwrap.json
			git checkout ${gameServerBranch}
			if [[ ! -d "node_modules" ]]; then
				npm --unsafe-perm i
				mkdir -p server/games/kingOfCoins/config/profiles/profile_cache/company/data/vikings/server/
				cp config/server_config/development-config.json server/games/kingOfCoins/config/profiles/profile_cache/company/data/vikings/server/development-config.json
			fi
			# Starts gameserver
			nohup npm run start:local > gameserver_${dateTime}.log &
			if [[ $? -eq 0 ]]; then
				green "gameserver started!"
				green "saving output to log at: ${scriptPath}/local_env/gameserver/gameserver_${dateTime}.log"
			else
				red "Unable to start gameserver!"
			fi
		else
			red "Not starting gameserver!"
			exit 0
		fi
	else # If gameserver is not running, start it
		cd ${scriptPath}/local_env/gameserver
		rm -f npm-shrinkwrap.json
		git checkout ${gameServerBranch}
		if [[ ! -d "node_modules" ]]; then
			npm --unsafe-perm i
			mkdir -p server/games/kingOfCoins/config/profiles/profile_cache/company/data/vikings/server/
			cp config/server_config/development-config.json server/games/kingOfCoins/config/profiles/profile_cache/company/data/vikings/server/development-config.json
		fi
		nohup npm run start:local > gameserver_${dateTime}.log &
		if [[ $? -eq 0 ]]; then
			green "gameserver started!"
			green "saving output to log at: ${scriptPath}/local_env/gameserver/gameserver_${dateTime}.log"
		else
			red "Unable to start gameserver!"
		fi
	fi
}

function buildDockerImages(){
	npmToken=$(cat ~/.npmrc | grep "_authToken" | awk -F= '{print $2}')
	if [[ $repo = 'all' ]]; then
		for ms in $msList; do
			yellow "Entering ${scriptPath}/local_env/microservice-${ms}"
			cd ${scriptPath}/local_env/microservice-${ms}
			if [[ -z $tag ]]; then
		  	gittag=$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/' -e 's/^ (//g' -e 's/)$//g' | tr "/" "-")
				green "Building docker image for repo ${ms} with tag ${gittag}"
		  	docker build -t ms-${ms}:"${gittag}" --build-arg=NODE_ENV='development' --build-arg=NPM_TOKEN="${npmToken}" .
			  cd ${scriptPath}
			  sed -i.bak "s/ms-${ms}.*/ms-${ms}:${gittag}/g" docker-compose.yml
				sed -i.bak "s/NPM_TOKEN:.*/NPM_TOKEN: '${npmToken}'/g" docker-compose.yml
			else
				green "Building docker image for repo microservice-${ms} with tag ${tag}"
		  	docker build -t ms-${ms}:"${tag}" --build-arg=NODE_ENV='development' --build-arg=NPM_TOKEN="${npmToken}" .
			  cd ${scriptPath}
			  sed -i.bak "s/ms-${ms}.*/ms-${ms}:${tag}/g" docker-compose.yml
				sed -i.bak "s/NPM_TOKEN:.*/NPM_TOKEN: '${npmToken}'/g" docker-compose.yml
			fi
		done
	else
		for ms in $(echo $repo | tr "," "\n"); do
		  yellow "Entering ${scriptPath}/local_env/microservice-${ms}"
		  cd ${scriptPath}/local_env/microservice-${ms}
			if [[ -z $tag ]]; then
		  	gittag=$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/' -e 's/^ (//g' -e 's/)$//g' | tr "/" "-")
				green "Building docker image for repo microservice-${ms} with tag ${gittag}"
		  	docker build -t ms-${ms}:"${gittag}" --build-arg=NODE_ENV='development' --build-arg=NPM_TOKEN="${npmToken}" .
			  cd ${scriptPath}
			  sed -i.bak "s/ms-${ms}.*/ms-${ms}:${gittag}/g" docker-compose.yml
				sed -i.bak "s/NPM_TOKEN:.*/NPM_TOKEN: '${npmToken}'/g" docker-compose.yml
			else
				green "Building docker image for repo microservice-${ms} with tag ${tag}"
		  	docker build -t ms-${ms}:"${tag}" --build-arg=NODE_ENV='development' --build-arg=NPM_TOKEN="${npmToken}" .
			  cd ${scriptPath}
			  sed -i.bak "s/ms-${ms}.*/ms-${ms}:${tag}/g" docker-compose.yml
				sed -i.bak "s/NPM_TOKEN:.*/NPM_TOKEN: '${npmToken}'/g" docker-compose.yml
			fi
		done
	fi
}

function UpStartCluster(){
  docker-compose up -d
}

function CheckAwsCliConfigured(){
	if [[ ! -s ~/.aws/credentials ]]; then
		red "AWS credentials are not set, gameserver will not be able to start! quiting!"
		red "Plesse configure aws cli before running this script again!"
		exit 1
	fi
}

function CleanUp(){
	sed -i.bak "s/NPM_TOKEN:.*/NPM_TOKEN: 'SECRET'/g" docker-compose.yml
	rm -f docker-compose.yml.bak
}

# Script starts here...
createBins
yamlLint
CheckAwsCliConfigured
repoVerification
buildDockerImages
UpStartCluster
CleanUp

docker ps -a

read -r -p "Would you like to start gameserver? [y/n] " answer
if [[ ${answer} = [Yy] ]]; then
	startGameserver
else
	red "Not starting gameserver!"
fi
