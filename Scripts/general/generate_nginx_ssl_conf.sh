#!/bin/bash
help() {
    echo "$0: Generates key, crt, nginx and ssl conf for a given domain name"
    echo "Usage: $0 [-d DOMAIN] -o option"
		echo "Avaiable options:          "
		echo "create"
		echo "delete"
		echo "display"
		echo "dockerpush"
}

if [[ "$#" -lt 4 ]]; then
	help
	exit
fi

# Color functions
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
NOCOLOR=`tput sgr0`

function colnormal {
	echo -e -n "$YELLOW $* $NOCOLOR\n"
}
function colgood {
	echo -e -n "$GREEN $* $NOCOLOR\n"
}
function colbad {
	echo -e -n "$RED $* $NOCOLOR\n"
}

function savetag {
  colnormal "Saving $TAG for later use..."
  echo "$TAG" >> /tmp/BSSL
}
# Arguments processing
while getopts ":d:o:" opt; do #domain, create, delete, display
	case $opt in
	d)
	  DOMAIN=$OPTARG
	;;
	o)
	  option=$OPTARG
	  case $option in
	    create)
	      ACTION="create"
	    ;;
	    delete)
	      ACTION="delete"
	    ;;
	    display)
	      ACTION="display"
	    ;;
	    dockerpush)
	      ACTION="dockerpush"
	    ;;
	  esac
	esac
done


# File location
NGINXCONF='./docker-conf' #geo
NGINXUSCONF='./lb01-conf/conf.d' #us
CERTSCONF='./ssl'
BSSLFILE=/tmp/BSSL
# PARAMETERS
TIME=$(date +%Y-%m-%d)
USER=$(whoami)
TAG="${TIME}-${USER}"
DOCKERHUBREPO="companyName-boost-ssl-docker"
DROPBOX=~/Dropbox/DevOps/SSL
REPO=~/src/boost-ssl-docker/ssl
CERTFILE="multi.$DOMAIN.cert"
KEYFILE="multi.$DOMAIN.key"
BUNDLEFILE="multi.$DOMAIN.bundle"
random=$((RANDOM))
tmpfile=$(mktemp /tmp/$random.tmp)

# Check if this is the first run
[ -f $BSSLFILE  ] && BSSL=$(cat $BSSLFILE) || true

# Code
case $ACTION in
	delete)
		colnormal "Chosen option: $ACTION, Domain: $DOMAIN"
		rm -f $REPO/$CERTFILE $REPO/$KEYFILE $NGINXCONF/$DOMAIN.conf $NGINXUSCONF/$DOMAIN.conf
		colgood "Cert, key and conf files have been deleted!"
		exit 0
	;;
	create)
		colnormal "Chosen option: $ACTION, Domain: $DOMAIN"
		# Check if certificate and key already exists
		if [ -f $REPO/$CERTFILE ]; then colbad "cert file already exists: $REPO/$CERTFILE, use the delete option first" ; exit 1 ; fi
		if [ -f $REPO/$KEYFILE ]; then colbad "key file already exists: $REPO/$KEYFILE, use the delete option first" ; exit 1 ; fi
		if [ -f "$NGINXUSCONF/$DOMAIN.conf" ]; then colbad "nginx site conf already exists: $NGINXUSCONF/$DOMAIN.conf, use the delete option first" ; exit 1 ; fi
		if [ -f "$NGINXCONF/$DOMAIN.conf" ]; then colbad "nginx conf already exists: $NGINXCONF/$DOMAIN.conf, use the delete option first" ; exit 1 ; fi
		#Prepare and Copy certificate to repo
		colgood "Bundling certificate, creating key, ssl and nginx configuration files!"
		find $DROPBOX/$DOMAIN -iname "*.crt" -exec cp {} $REPO/$CERTFILE \;
		find $DROPBOX/$DOMAIN -iname "*.key" -exec cp {} $REPO/$KEYFILE \;
		echo >> $REPO/$CERTFILE
		find $DROPBOX/$DOMAIN -iname "*bundle*" -exec cat {} >> $REPO/$CERTFILE \;

		if [ -z "$CERTSCONF/$CERTFILE" ] || [ -z "$CERTSCONF/$KEYFILE" ]; then echo "Failed to find certificate or it's key in $CERTSCONF" ; exit 1; fi
		if [ -f "$NGINXCONF/$DOMAIN.conf" ]; then
			colbad "nginx conf already exist: $NGINXCONF/$DOMAIN.conf"
		else
			cat <<EOF > $NGINXCONF/$DOMAIN.conf
server {
  listen 443 ssl http2;
  server_name $DOMAIN www.$DOMAIN cdn.$DOMAIN m.$DOMAIN cdn.m.$DOMAIN;

  ssl on;
  ssl_certificate         /etc/nginx/ssl/$CERTFILE;
  ssl_certificate_key     /etc/nginx/ssl/$KEYFILE;

location / {
    proxy_pass http://haproxy:80;
    proxy_redirect off;
    proxy_set_header      X-NginX-Proxy true;
    proxy_set_header      Host \$http_host;
    proxy_set_header      X-Real-IP  \$remote_addr;
    proxy_set_header      X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header      X-Forwarded-Proto https;
  }
}
EOF

	cat <<EOF > $NGINXUSCONF/$DOMAIN.conf
server {
      listen 443;
      server_name $DOMAIN www.$DOMAIN cdn.$DOMAIN m.$DOMAIN cdn.m.$DOMAIN;

      ssl on;
      ssl_certificate         /etc/nginx/ssl/$CERTFILE;
      ssl_certificate_key     /etc/nginx/ssl/$KEYFILE;

location / {
    proxy_pass http://main;
        proxy_redirect off;
        proxy_set_header      X-NginX-Proxy true;
        proxy_set_header      Host \$http_host;
        proxy_set_header      X-Real-IP  \$remote_addr;
        proxy_set_header      X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header      X-Forwarded-Proto https;
      }
    }
EOF
	read -r -p "Build docker image? [y/n]: " dockerbuild
	if [[ $dockerbuild = "y" ]]; then
	  docker build --no-cache -t $DOCKERHUBREPO:$TAG -t $DOCKERHUBREPO:latest .
	  docker-compose -f boost-ssl-docker-test-compose.yml up -d
	  if [[ $? -eq 0 ]]; then
	    colgood "Docker-Compose started successfully!"
	    read -r -p "Push docker images to DockerHub? [y/n] " pushdocker
	    if [[ $pushdocker = "y" ]]; then
	      docker push $DOCKERHUBREPO:$TAG
	      docker push $DOCKERHUBREPO:latest
	      if [[ "$?" -eq "0" ]]; then
		colgood "Docker image has been pushed successfully to DockerHub"
		colgood "Tag to use when running deploy job in Jenkins: $TAG"

	      else
		colbad "Docker image failed being pushed to DockerHub"
	      fi
	    elif [[ $pushdocker = "n" ]]; then
	      colnormal "Docker-compose started successfully, but user chose not to push images to DockerHub!"
	      savetag
	      exit 0
	    fi
	  else
	    colbad "Docker-compose failed!"
	    exit 1
	  fi
	  elif [[ $dockerbuild = "n" ]]; then
	    colnormal "Not building docker image and exiting"
	    exit 0
	  fi
	fi
;;
dockerpush)
  docker push $DOCKERHUBREPO:$BSSL
  docker push $DOCKERHUBREPO:latest
  rm -f $BSSLFILE
;;
display)
  colnormal "Chosen option: $ACTION, Domain: $DOMAIN"
  echo "$REPO/$CERTFILE $REPO/$KEYFILE $NGINXCONF/$DOMAIN.conf $NGINXUSCONF/$DOMAIN.conf" >> $tmpfile
  for file in $(cat $tmpfile); do
    colnormal "=================== $file: =================== "
    cat $file
  done
  ;;
*)
  help
  exit
  ;;
esac
