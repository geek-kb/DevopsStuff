#!/bin/bash -xe
# Script by Itai Ganot 2018

# Vars
bucket="BUCKET_NAME"
zabbix_ip="zabbix.company.com"
fbconf="filebeat.yml"
etcfb="/etc/filebeat"
bucket="s3://$bucket/emr_cluster_creation"

# Name of log type as parsed by Logz.io - chosen in Jenkins
FileBeatLogName=$1

# Install python and pip
sudo yum install -y python2 pip
pip install awscli --upgrade --user

# Download and install filebeat
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-6.4.0-x86_64.rpm
sudo rpm -vi filebeat-6.4.0-x86_64.rpm

# Download filebeat configuration
aws s3 cp ${bucket}/${fbconf} .

# Configure filebeat log type name to be displayed in Logz.io
sed -i "s/TYPE/${FileBeatLogName}/g" ${fbconf}
sudo mv ${fbconf} ${etcfb}/
sudo chown root:root ${etcfb}/${fbconf}
sudo chmod go-w ${etcfb}/${fbconf}

# Configure redirection of logs to logz.io
wget https://raw.githubusercontent.com/logzio/public-certificates/master/COMODORSADomainValidationSecureServerCA.crt
sudo mkdir -p /etc/pki/tls/certs
sudo cp COMODORSADomainValidationSecureServerCA.crt /etc/pki/tls/certs/

# Start FileBeat
sudo service filebeat restart

# Zabbix installation
cat > zabbix.tmp << EOF
PidFile=/var/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=1
DebugLevel=3
Server=$zabbix_ip
ServerActive=$zabbix_ip
EnableRemoteCommands=1
Include=/etc/zabbix/zabbix_agentd.d
EOF

ZABBIX_INSTALLATION="1"
if [[ $ZABBIX_INSTALLATION="1" ]];then
    echo "Installing zabbix client"
    #sudo yum update -y
    sudo rpm -Uvh http://repo.zabbix.com/zabbix/3.4/rhel/6/x86_64/zabbix-release-3.4-1.el6.noarch.rpm
    sudo yum install zabbix-agent -y
    sudo mv zabbix.tmp /etc/zabbix/zabbix_agentd.conf
    sudo /etc/init.d/zabbix-agent restart
else
	rm -f zabbix.tmp
fi

# node_exporter installation
sudo useradd -s /sbin/nologin node_exporter
curl https://gist.githubusercontent.com/eloo/a06d7c70ff2a841b7bb98cd322b851b9/raw/38460167a47938b718691c5be56c9eeb56df8530/node_exporter.init.d > node_exporter
sed -i 's/DAEMON=.*/DAEMON=\/usr\/sbin\/node_exporter/g' node_exporter
sed -i 's/USER=.*/USER=node_exporter/g' node_exporter
chmod u+x node_exporter
sudo mv node_exporter /etc/init.d/
wget https://github.com/prometheus/node_exporter/releases/download/v0.16.0/node_exporter-0.16.0.linux-amd64.tar.gz
tar -xvzf node_exporter-0.16.0.linux-amd64.tar.gz
cd node_exporter-0.16.0.linux-amd64/
chmod u+x node_exporter
sudo mv node_exporter /usr/sbin/
sudo /etc/init.d/node_exporter start
sudo chkconfig --add node_exporter
sudo chkconfig --level 345 node_exporter on
curl -s 'http://localhost:9100/metrics' > /dev/null

