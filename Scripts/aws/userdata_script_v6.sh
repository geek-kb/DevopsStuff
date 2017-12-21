#!/bin/bash -ex
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Echoes all commands before executing.
set -o verbose

SECONDS=0

echo BEGIN

############################################################
#Print parameters:
echo "envtype: $envtype"
echo "envname: $envname"
# Create the env Variables
lowerenvtype=`echo "${envtype,,}"`
lowerenvname=`echo "${envname,,}"`
echo "Number of Analytics servers: $analyticsnum"
############################################################
#------------------------------------------------ environment parameters ----------------------------------------------#
if [[ $envname = "Cassandra" ]]; then
  homedir="/home/bitnami"
elif [[ $envname = "Bastion" ]]; then
  homedir="/home/ec2-user"
else
  homedir="/home/company"
fi
logfile="${homedir}/debug.log"
touch $logfile
# ------------------------------------------------ helper methods------------------------------------------------------#
function log {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%S.000')]: $*" >> $logfile
}

function error_exit
{
    echo "$1" 1>&2
    exit 1
}

function count_asg_servers
{
    asgname=$(aws autoscaling describe-auto-scaling-groups --region $region | grep ResourceId | grep $envtype-$buildnumber-$envname | tr -d '\"|,' | uniq | awk '{print $2}')
    log echo "(In function) asgname : $asgname"
    current_servers=$(aws ec2 describe-instances --instance-ids $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "${asgname}" --region $region | grep InstanceId | awk -F: '{print $2}' | tr -d '\"|,' | tr -d '\n') --region $region | grep "PrivateIpAddress" | grep -v '\[' | awk -F: '{print $2}' | uniq -u | tr -d '\"|,' )
    log echo "(In function) current_servers : $current_servers"
    current_stack_servers_count=$(echo "${current_servers}" | wc -l)
    log echo "(In function) current_stack_servers_count : $current_stack_servers_count"
}

function find_cassandra_asg_name
{
  asgname=$(aws autoscaling describe-auto-scaling-groups --region $region | grep ResourceId | grep $envtype-$buildnumber-$envname | tr -d '\"|,' | uniq | awk '{print $2}')
  log echo "(In function) asgname : $asgname"
  current_servers=$(aws ec2 describe-instances --instance-ids $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "${asgname}" --region $region | grep InstanceId | awk -F: '{print $2}' | tr -d '\"|,' | tr -d '\n') --region $region | grep "PrivateIpAddress" | grep -v '\[' | awk -F: '{print $2}' | uniq | tr -d '\"|,')
  log echo "(In function) current_servers : $current_servers"
  current_stack_servers_count=$(echo "${current_servers}" | wc -l)
  log echo "(In function) current_stack_servers_count : $current_stack_servers_count"
}
# ------------------------------------------------ versions -----------------------------------------------------------#
LIQUIBASE_VERSION=3.5.3
JAVA_MINOR=111
JAVA_VERSION=8u${JAVA_MINOR}
KAFKA_VERSION=2.11-0.10.1.1
KAFKA_ZOOKEEPER_MANAGER_VERSION=0.0.1-SNAPSHOT
TRIFECTA_VERSION=0.21.3
CASSANDRA_VERSION=3.9
CASSANDRA_SCHEME_VERSION=0.0.1-SNAPSHOT
# -------------------------------------------------------------------------------------------------------------------- #
#for dev
REDIS_VERSION=3.2.0

### Userdata script for Angelsense ${envname}
# ------------------------------------------------ Extract Scripts ----------------------------------------------------#
if wget -O ${homedir}/ops.zip https://s3-us-west-2.amazonaws.com/company-ci-files/ops.zip; then
  if [[ $envname != "Cassandra" ]]; then
    unzip ${homedir}/ops.zip -d ${homedir}
    rm -f ${homedir}/ops.zip
    /bin/cp -f ${homedir}/ops/${lowerenvname}/scripts/*.sh ${homedir}
    chmod +x ${homedir}/*.sh
  elif [[ $envname = "Cassandra" ]]; then
    unzip ${homedir}/ops.zip -d ${homedir}
    rm -f ${homedir}/ops.zip
    chown -R bitnami:bitnami ${homedir}
  fi
else
    error_exit "Cannot get ops.zip!  Aborting."
fi
# ------------------------------------------------ AWS setup ----------------------------------------------------------#
#install config for aws commands
mkdir ${homedir}/.aws
cp ${homedir}/ops/global/aws/* ${homedir}/.aws
mkdir ~/.aws
cp ${homedir}/ops/global/aws/*  ~/.aws

if [[ $envname = "Cassandra" ]]; then
  sudo pip install --upgrade pip
  sudo pip install awscli
  sleep 5
  source ~/.bashrc
  echo "amazon cli version"
  aws --version
  export PATH=$PATH:/opt/bitnami/python/bin/
  export region=$region
  export envname=$envname
  export envtype=$envtype
  export buildnumber=$buildnumber
fi
#########################################################################################################################
if [[ "$envname" = "Cassandra" ]]; then
  find_cassandra_asg_name
else
  count_asg_servers
fi
echo "asgname: $asgname"
case $envname in
  "Api")
    lowerenvname="api"
  ;;
  "Batch")
    lowerenvname="batch"
  ;;
  "Analytics")
    lowerenvname="analytics"
  ;;
  "Cassandra")
    lowerenvname="cassandra"
  ;;
  "Bastion")
    lowerenvname="bastion"
  ;;
esac
echo "${lowerenvtype}-${lowerenvname}-${buildnumber}" >> /etc/envtype.txt

INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)

#if [[ $envname = "Bastion" ]]; then
#  if [[ $region = "us-east-1" ]]; then
#    vgEipAllocationId="eipalloc-317b7404"
#    aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $vgEipAllocationId --region $region
#  else
#    #assign elastic ip
#    echo "assign elastic ip"
#    echo "elasticip: "  ${elasticip}
#    aws ec2 associate-address --instance-id $INSTANCE_ID --public-ip $elasticip --region $region
#    cp ${homedir}/ops/global/system/ipassign.sh /etc/init.d/ipassign
#    chmod +x /etc/init.d/ipassign
#    sed -i "s|ELASTIC_POOL|${elasticip}|g" /etc/init.d/ipassign
#    /etc/init.d/ipassign start
#    chkconfig --add ipassign
#    chkconfig ipassign on --level 3
#  fi
#fi

#install json parser for network interface
if wget http://stedolan.github.io/jq/download/linux64/jq; then
    chmod +x ./jq
    cp jq /usr/bin
else
    error_exit "Cannot get jq. !Aborting."
fi

sleep 5s

servers_array=()

echo "asgname : $asgname"
for instance in $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $asgname --region $region | grep InstanceId | awk '{print $2}' | tr -d '\"|,'); do
    servers_array+=($instance)
done

for i in "${!servers_array[@]}"; do
  echo "DEBUG: $i - ${servers_array[$i]}"
  if [[ "${servers_array[$i]}" = "$INSTANCE_ID" ]]; then
    AMI_LAUNCH_INDEX=$i
    log echo "(inside servers_array) AMI_LAUNCH_INDEX : $AMI_LAUNCH_INDEX"
  fi
done

# AMI_LAUNCH_BASE used to set a servers hostname
AMI_LAUNCH_BASE=$((AMI_LAUNCH_INDEX+1))

# If ASG name contains API and number of servers is greater than 2, fix AMI_LAUNCH_INDEX accordingly
if [[ $asgname == *"Api"* ]]; then
    log echo "current_stack_servers_count : $current_stack_servers_count"
    if [ "$current_stack_servers_count" -gt "2" ]; then
      AMI_LAUNCH_INDEX=$((current_stack_servers_count-1))
      AMI_LAUNCH_BASE="$current_stack_servers_count"
    fi
elif [[ $asgname == *"Cassandra"* ]]; then
  if [ "$current_stack_servers_count" -ge "1" ]; then
    servers_array=()

    echo "asgname : $asgname"
    for instance in $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $asgname --region $region | grep InstanceId | awk '{print $2}' | tr -d '\"|,'); do
        servers_array+=($instance)
    done

    for i in "${!servers_array[@]}"; do
      echo "DEBUG: $i - ${servers_array[$i]}"
      if [[ "${servers_array[$i]}" = "$INSTANCE_ID" ]]; then
        AMI_LAUNCH_INDEX=$i
        log echo "(inside servers_array) AMI_LAUNCH_INDEX : $AMI_LAUNCH_INDEX"
      fi
    done
    AMI_LAUNCH_BASE=$((AMI_LAUNCH_INDEX+1))
    cluster=true
  fi
fi

if [[ $envname != "Cassandra" && $envname != "Bastion" ]]; then
  apiIPa=${lowerenvtype}-api1.${vpcid}.${region}.company.private
  apiIPb=${lowerenvtype}-api2.${vpcid}.${region}.company.private
  analyticsIPa=${lowerenvtype}-analytics1.${vpcid}.${region}.company.private
  analyticsIPb=${lowerenvtype}-analytics2.${vpcid}.${region}.company.private
  batchIP=${lowerenvtype}-batch1.${vpcid}.${region}.company.private
  camelEnvName=`echo ${envname} | sed -re "s~(^|_)(.)~\U\2~g"`

  # Set host name
  cp ${homedir}/ops/global/system/companyinit.sh /etc/init.d/companyinit
  chmod +x /etc/init.d/companyinit
  chkconfig --add companyinit
  chkconfig companyinit on --level 3
fi
localip=`ifconfig eth0 | awk '/inet addr/{print substr($2,6)}' | grep 17`

# Mysql Vars
MysqlHostname="${lowerenvtype}-mysql.${vpcid}.${region}.company.private"
RDSDBEndpointHost=${mysql_server}
#RDSDBEndpointIp=$(nslookup $RDSDBEndpointHost | grep -A1 $RDSDBEndpointHost | grep -v Name | awk '{print $2}')

# Hostname management
hn=${teamname}-${envtype}-${envname}-${buildnumber}-I${AMI_LAUNCH_INDEX}
case $envname in
  "Cassandra")
  lowerenvtype=$(echo "${envtype,,}")
  lowerenvname=$(echo "${envname,,}")
  sudo hostname $hn
  sudo -- sh -c "echo 127.0.0.1 $hn.company-private $hn >> /etc/hosts" &>/dev/null
  currentDns=${lowerenvtype}-${lowerenvname}${AMI_LAUNCH_BASE}.${vpcid}.${region}.company.private
  echo "currentDns: " ${currentDns}
  sudo -- sh -c "echo ${currentDns} >> /etc/currentDns.txt"
;;
"Bastion")
  hostname $hn
  currentDns=${lowerenvtype}-${lowerenvname}.${vpcid}.${region}.company.private
  sed -i.bak -e "s/^HOSTNAME=.*$/HOSTNAME=$hn.company/" /etc/sysconfig/network
  echo 127.0.0.1 $hn.company $hn ${currentDns} >> /etc/hosts
  echo "currentDns: " ${currentDns}
  echo "${currentDns}" >> /etc/currentDns.txt
;;
"Batch")
  # Update route53 with a cname which points to RDS endpoint
  cp ${homedir}/ops/global/aws/change-resource-record-set-mysql.json ${homedir}/change-resource-record-set-mysql.json
  sed -i "s|MysqlHostname|${MysqlHostname}|g" ${homedir}/change-resource-record-set-mysql.json
  sed -i "s|RDSDBEndpointHost|${RDSDBEndpointHost}|g" ${homedir}/change-resource-record-set-mysql.json
  aws route53 change-resource-record-sets --hosted-zone-id $hostedzoneid --change-batch file://${homedir}/change-resource-record-set-mysql.json
  #rm ${homedir}/change-resource-record-sets.json

  # Configures hostname
  hostname $hn
  sed -i.bak -e "s/^HOSTNAME=.*$/HOSTNAME=$hn.company/" /etc/sysconfig/network
  echo 127.0.0.1 $hn.company $hn >> /etc/hosts
  currentDns=${lowerenvtype}-${lowerenvname}${AMI_LAUNCH_BASE}.${vpcid}.${region}.company.private
  echo "currentDns: " ${currentDns}
  echo "${currentDns}" >> /etc/currentDns.txt
;;
*)
  hostname $hn
  sed -i.bak -e "s/^HOSTNAME=.*$/HOSTNAME=$hn.company/" /etc/sysconfig/network
  echo 127.0.0.1 $hn.company $hn >> /etc/hosts
  currentDns=${lowerenvtype}-${lowerenvname}${AMI_LAUNCH_BASE}.${vpcid}.${region}.company.private
  echo "currentDns: " ${currentDns}
  echo "${currentDns}" >> /etc/currentDns.txt
;;
esac

#assign private ip
localip=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
echo "assign private ip"
echo "localip" ${localip}

# Configure dns
if [[ $envname = "Cassandra" ]]; then
  homedir="/home/bitnami"
fi

PUBLIC_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
if [[ $envname = "Bastion" ]]; then
  # Register bastion to dns with public ip
  localip=$PUBLIC_IP
fi
# Route53 host registration
cp ${homedir}/ops/global/aws/change-resource-record-sets.json ${homedir}/change-resource-record-sets.json
sed -i "s|localIP|${localip}|g" ${homedir}/change-resource-record-sets.json
sed -i "s|currentDns|${currentDns}|g" ${homedir}/change-resource-record-sets.json
aws route53 change-resource-record-sets --hosted-zone-id $hostedzoneid --change-batch file://${homedir}/change-resource-record-sets.json
rm ${homedir}/change-resource-record-sets.json

# Instance Tags creation
aws ec2 create-tags --resources $INSTANCE_ID --tags Key=hostname,Value=$currentDns --region $region
aws ec2 create-tags --resources $INSTANCE_ID --tags Key=PublicIp,Value=$PUBLIC_IP --region $region
aws ec2 create-tags --resources $INSTANCE_ID --tags Key=PrivateIP,Value=$localip --region $region
aws ec2 create-tags --resources $INSTANCE_ID --tags Key=InstanceId,Value=$INSTANCE_ID --region $region

if [[ "$envname" != "Cassandra" && "$envname" != "Bastion" ]]; then
  # ------------------------------------------------ app parameters------------------------------------------------------#
  #INSTALL_LIQIBASE=false
  case $lowerenvname in
      analytics)
      INSTALL_LIQIBASE=true
      if [[ $AMI_LAUNCH_INDEX -eq 0 ]]; then
        UNIQUE_ID=10
        kafkaHost=true
      elif [[ $AMI_LAUNCH_INDEX -eq 1 ]]; then
        UNIQUE_ID=11
        kafkaHost=false
      fi
      ;;
      batch)
      UNIQUE_ID=20
      kafkaHost=true
      INSTALL_LIQIBASE=true
      ;;
      api)
      if [[ $AMI_LAUNCH_INDEX -eq 0 ]]; then
          UNIQUE_ID=30
          kafkaHost=true
      elif [[ $AMI_LAUNCH_INDEX -eq 1 ]]; then
          UNIQUE_ID=31
          kafkaHost=true
      fi
      ;;
  esac

  # ------------------------------------------------ cassandra -----------------------------------------------------------#
  INSTALL_CASSANDRA=true
  if [ "$INSTALL_CASSANDRA" == true ] && [ "$lowerenvname" == "batch" ]; then
      echo 'installing cassandra'
      if aws s3 cp s3://company-ci-files/apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz ${homedir}/apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz; then
          cassandra_dir=${homedir}/apache-cassandra-${CASSANDRA_VERSION}
          tar -zxvf ${homedir}/apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz -C ${homedir}
          ln -s ${cassandra_dir} ${homedir}/cassandra

          sudo mkdir /var/lib/cassandra
          sudo mkdir /var/log/cassandra
          sudo chown -R company:company /var/lib/cassandra
          sudo chown -R company:company /var/log/cassandra

          #set config
          sed -i "s|rpc_address: localhost|rpc_address: ${localip}|g" ${cassandra_dir}/conf/cassandra.yaml
          #sed -i "s|listen_address: localhost|listen_address: ${localip}|g" ${cassandra_dir}/conf/cassandra.yaml

          echo 'CASSANDRA_HOME=/home/company/cassandra' >> ${homedir}/.bash_profile
          rm ${homedir}/apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz
      else
          error_exit "Cannot get cassandra!  Aborting."
      fi

      if aws s3 cp s3://company-ci-files/cassandra-scheme-${CASSANDRA_SCHEME_VERSION}.jar ${homedir}/deploy/cassandra-scheme/cassandra-scheme-${CASSANDRA_SCHEME_VERSION}.jar; then
          ln -s ${homedir}/deploy/cassandra-scheme/cassandra-scheme-${CASSANDRA_SCHEME_VERSION}.jar ${homedir}/deploy/cassandra-scheme/cassandra-scheme.jar
          mkdir ${homedir}/deploy/cassandra-scheme/config
          touch ${homedir}/deploy/cassandra-scheme/config/application.properties
          properKeyStore=`echo ${lowerenvtype} | tr "-" "_"`
          echo properKeyStore $properKeyStore
          echo -e "cassandra.keyspace=company_"${properKeyStore} >> ${homedir}/deploy/cassandra-scheme/config/application.properties
          echo -e "cassandra.contactpoints=${lowerenvtype}-cassandra1.${vpcid}.${region}.company.private" >> ${homedir}/deploy/cassandra-scheme/config/application.properties
          echo -e "scheme.dir=/home/company/deploy/current/cassandra"  >> ${homedir}/deploy/cassandra-scheme/config/application.properties
          echo -e "cassandra.user=${cassandraUser}"  >> ${homedir}/deploy/cassandra-scheme/config/application.properties
          echo -e "cassandra.password=${cassandraPassword}"  >> ${homedir}/deploy/cassandra-scheme/config/application.properties
      fi

      cp ${homedir}/ops/cassandra/cassandraCLI.sh ${homedir}/cassandraCLI.sh
      chmod +x ${homedir}/cassandraCLI.sh
      sed -i "s|password|${cassandraPassword}|g" ${homedir}/cassandraCLI.sh
      sed -i "s|cassandraIp|${lowerenvtype}-cassandra1.${vpcid}.${region}.company.private|g" ${homedir}/cassandraCLI.sh
  fi

  # ------------------------------------------------ liqibase -----------------------------------------------------------#
  if [ "$INSTALL_LIQIBASE" == true ] ; then
      echo 'installing liqibase'

      liquibase_dir=${homedir}/deploy/liquibase-${LIQUIBASE_VERSION}
      if aws s3 cp s3://company-ci-files/liquibase-${LIQUIBASE_VERSION}-bin.tar.gz ${homedir}/liquibase-${LIQUIBASE_VERSION}-bin.tar.gz; then
          echo "downloaded " liquibase-${LIQUIBASE_VERSION}-bin.tar.gz
      else
          error_exit "Cannot get ops.zip!  Aborting."
      fi
      mkdir -p ${liquibase_dir}
      tar -zxvf ${homedir}/liquibase-${LIQUIBASE_VERSION}-bin.tar.gz -C ${liquibase_dir}
      ln -s ${liquibase_dir} ${homedir}/deploy/liquibase

      if aws s3 cp s3://company-ci-files/mysql-connector-java-5.1.39-bin.jar ${liquibase_dir}/lib/mysql-connector-java-5.1.39-bin.jar; then
          echo "downloaded mysql-connector-java-5.1.39-bin.jar"
      else
          error_exit "Cannot get ops.zip!  Aborting."
      fi

      dburl=$MysqlHostname
      cp ${homedir}/ops/global/system/liquibase.properties ${liquibase_dir}/liquibase.properties
      sed -i "s|DB_SCHEME|${dbscheme}|g" ${liquibase_dir}/liquibase.properties
      sed -i "s|DB_ADMIN_USER|${dbadminuser}|g" ${liquibase_dir}/liquibase.properties
      sed -i "s|DB_PASS|${dbpass}|g" ${liquibase_dir}/liquibase.properties
      sed -i "s|DB_URL|${dburl}|g" ${liquibase_dir}/liquibase.properties
      rm ${homedir}/liquibase-${LIQUIBASE_VERSION}-bin.tar.gz
  fi

  # ------------------------------------------------ kafka ------------------------------------------------------#
  # The following command gets the hosts specified in the zone-id(company.private) and enters them in the "zookeeper.connect=" directive in kafka server.properties
  #log echo devservers=$(aws route53 list-resource-record-sets --hosted-zone-id Z1ZOGSXD2823ZV --region us-west-2 | grep -i dev | grep -v "cassandra\|db\|rds" | awk -F: '{print $2}' | tr -d '\"|,' | awk -F. '{print $1"."$2}' | sed 's|$|:2181|' | tr '\n' ',' | sed 's|.$||' | tr -d ' ')
  #log echo asgname=$(aws autoscaling describe-auto-scaling-groups --region us-west-2| grep -i ${lowerenvtype} | grep ResourceId | grep -i ${lowerenvname} | uniq | awk -F: '{print $2}' | tr -d '\"|,' | tr ' ' '\n' | sort -n | tail -n 1)
  #log echo current_servers=$(aws ec2 describe-instances --instance-ids $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $asgname --region us-west-2 | grep InstanceId | awk -F: '{print $2}' | tr -d '\"|,' | tr -d '\n') --region us-west-2 | grep "PrivateIpAddress" | grep -v '\[' | awk -F: '{print $2}' | tr -d '\"|,' | uniq  | tr '\n' ' ')
  log echo current_stack_servers_count=$(echo $current_stack_servers_count | wc -l)

  touch ${homedir}/debug.log
  log echo "asgname : $asgname"

  if [[ "$current_stack_servers_count" -ge "0" && "$current_stack_servers_count" -le "2" ]]; then
    ## fetch kakfa zip from s3
    #aws s3 cp s3://company-ci-files/kafka_${KAFKA_VERSION}.tgz ${homedir}/kafka.tgz; then
    if aws s3 cp s3://company-ci-files/kafka_${KAFKA_VERSION}.tgz ${homedir}/kafka.tgz; then
        ## unzip kafka zip
        tar -vxf ${homedir}/kafka.tgz -C ${homedir}/

        ## link folder to kakfa.
        ln -s ${homedir}/kafka_${KAFKA_VERSION} ${homedir}/kafka
        kafkaLogDir=${homedir}/kafka/logs-data
        mkdir -p ${kafkaLogDir}

        #copy & fix property file
        cp ${homedir}/ops/global/kafka/server.properties ${homedir}/kafka/config/server.properties
        cp ${homedir}/ops/global/kafka/zookeeper.properties ${homedir}/kafka/config/zookeeper.properties

        #configure logrotate for kafka
        cp ${homedir}/ops/global/system/kafka.logrotate /etc/logrotate.d/kafka

        sed -i "s/changeToHost/${localip}/g" ${homedir}/kafka/config/server.properties
        sed -i "s/changeBrokerId/$UNIQUE_ID/g" ${homedir}/kafka/config/server.properties

        zookeeperDir=${homedir}/kafka/zookeeper/data
        mkdir -p ${zookeeperDir}

        sed -i "s|LOG_DIR|${kafkaLogDir}|g" ${homedir}/kafka/config/server.properties
        sed -i "s|changeToHost|${localip}|g" ${homedir}/kafka/config/server.properties
        sed -i "s|apiIPa|${apiIPa}|g" ${homedir}/kafka/config/server.properties
        sed -i "s|apiIPb|${apiIPb}|g" ${homedir}/kafka/config/server.properties
        sed -i "s|analyticsIPa|${analyticsIPa}|g" ${homedir}/kafka/config/server.properties
        if [[ $analyticsnodes -ge "2" ]]; then
          sed -i "s|analyticsIPb|${analyticsIPb}|g" ${homedir}/kafka/config/server.properties
        else
          sed -i 's|analyticsIPb:2181,||g' ${homedir}/kafka/config/server.properties
        fi
        sed -i "s|batchIP|${batchIP}|g" ${homedir}/kafka/config/server.properties
        sed -i "s|changeDataDir|${zookeeperDir}|g" ${homedir}/kafka/config/zookeeper.properties
        sed -i "s|apiIPa|${apiIPa}|g" ${homedir}/kafka/config/zookeeper.properties
        sed -i "s|apiIPb|${apiIPb}|g" ${homedir}/kafka/config/zookeeper.properties
        sed -i "s|analyticsIPa|${analyticsIPa}|g" ${homedir}/kafka/config/zookeeper.properties
        if [[ $analyticsnodes -ge "2" ]]; then
          sed -i "s|analyticsIPb|${analyticsIPb}|g" ${homedir}/kafka/config/zookeeper.properties
        else
          sed -i 's|analyticsIPb:2181,||g' ${homedir}/kafka/config/zookeeper.properties
        fi
        sed -i "s|batchIP|${batchIP}|g" ${homedir}/kafka/config/zookeeper.properties

        rm ${homedir}/kafka.tgz
        chown -R company:company ${homedir}/*
        chown -R company:company /var/log/kafka-logs
    fi
      #sed -i "s|zookeeper.connect=.*|zookeeper.connect=${devservers}|g" ${homedir}/kafka/config/server.properties
      log echo "UNIQUE_ID: ${UNIQUE_ID}"
      echo "${UNIQUE_ID}" > "${zookeeperDir}/myid"

      if [[ $kafkaHost = true ]]; then
        # Register kafka node hostname in Route53
        kafkaDnsName="${lowerenvtype}-kafka-${UNIQUE_ID}.${vpcid}.${region}.company.private"
        cp ${homedir}/ops/global/aws/change-resource-record-sets.json ${homedir}/change-resource-record-sets.json
        sed -i "s|localIP|${localip}|g" ${homedir}/change-resource-record-sets.json
        sed -i "s|currentDns|${kafkaDnsName}|g" ${homedir}/change-resource-record-sets.json
        aws route53 change-resource-record-sets --hosted-zone-id $hostedzoneid --change-batch file://${homedir}/change-resource-record-sets.json
        rm ${homedir}/change-resource-record-sets.json
      fi
  #   else
  #       error_exit "Cannot get kafka!  Aborting."
  #   fi

      # ------------------------------------------------ Monitor Utils ------------------------------------------------------#
  #setup monitor
  monitordir=${homedir}/monitor
  mkdir -p ${monitordir}

      if aws s3 cp s3://company-ci-files/zookeeper-kafka-monitor-${KAFKA_ZOOKEEPER_MANAGER_VERSION}.jar ${monitordir}/zookeeper-kafka-monitor/zookeeper-kafka-monitor.jar; then
          mkdir ${monitordir}/zookeeper-kafka-monitor/config
          touch ${monitordir}/zookeeper-kafka-monitor/config/application.properties
          #echo -e "zookeeper.connections=" ${apiIP}:2181,${analyticsIP}:2181,${batchIP}:2181 >> ${monitordir}/zookeeper-kafka-monitor/config/application.properties
          echo "zookeeper.connect=${devservers}" >> ${monitordir}/zookeeper-kafka-monitor/config/application.properties
          cp ${homedir}/ops/global/kafka/zkstatus.sh ${monitordir}/zkstatus.sh
          chmod +x ${monitordir}/zkstatus.sh
          sed -i "s|apiIPa|${apiIPa}|g" ${monitordir}/zkstatus.sh
          sed -i "s|apiIPb|${apiIPb}|g" ${monitordir}/zkstatus.sh
          sed -i "s|analyticsIPa|${analyticsIPa}|g" ${monitordir}/zkstatus.sh
          if [[ $analyticsnodes -ge "2" ]]; then
            sed -i "s|analyticsIPb|${analyticsIPb}|g" ${monitordir}/zkstatus.sh
          else
            sed -i "s|analyticsIPb:2181,||g" ${monitordir}/zkstatus.sh
          fi
          sed -i "s|batchIP|${batchIP}|g" ${monitordir}/zkstatus.sh

          cp ${homedir}/ops/global/kafka/zktop.py ${monitordir}/zktop.py
          chmod +x ${monitordir}/zktop.py

          cp ${homedir}/ops/global/kafka/zktop.sh ${monitordir}/zktop.sh
          chmod +x ${monitordir}/zktop.sh
          sed -i "s|apiIPa|${apiIPa}|g" ${monitordir}/zktop.sh
          sed -i "s|apiIPb|${apiIPb}|g" ${monitordir}/zktop.sh
          sed -i "s|analyticsIPa|${analyticsIPa}|g" ${monitordir}/zktop.sh
          if [[ $analyticsnodes -ge "2" ]]; then
            sed -i "s|analyticsIPb|${analyticsIPb}|g" ${monitordir}/zktop.sh
          else
            sed -i "s|analyticsIPb:2181,||g" ${monitordir}/zkstatus.sh
          fi
          sed -i "s|batchIP|${batchIP}|g" ${monitordir}/zktop.sh
      	else
          error_exit "Cannot get kafka monitor!  Aborting."
      	fi

      #------------------------------------------------ kafka trifecta_ui ----------------------------------------------------#
      ## fetch ui zip from s3
      if aws s3 cp s3://company-ci-files/trifecta_ui-${TRIFECTA_VERSION}.zip ${monitordir}/trifecta_ui-${TRIFECTA_VERSION}.zip; then

          ## unzip
          unzip ${monitordir}/trifecta_ui-${TRIFECTA_VERSION}.zip  -d ${monitordir}/
          rm ${monitordir}/trifecta_ui-${TRIFECTA_VERSION}.zip

          ln -s ${monitordir}/trifecta_ui-${TRIFECTA_VERSION} ${monitordir}/trifecta_ui

          chown -R company:company ${monitordir}/trifecta_ui-${TRIFECTA_VERSION}

          mkdir ${homedir}/.trifecta
          mkdir ${homedir}/.trifecta/decoders
          mkdir ${homedir}/.trifecta/queries

          cp ${homedir}/ops/global/kafka/trifecta/config.properties ${homedir}/.trifecta/config.properties
          sed -i "s/changeToHost/${currentDns}/g" ${homedir}/.trifecta/config.properties


          chown -R company:company ${homedir}/.trifecta
      else
          error_exit "Cannot get trifecta_ui!  Aborting."
      fi
  else
      echo "DEBUG current_servers_count not in range!"
  fi

  echo "------------------------------------------------ zabbix ---------------------------------------------------------"
  rm /etc/zabbix/zabbix_agentd.d/*
  cp ${homedir}/ops/${lowerenvname}/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf
  cp ${homedir}/ops/${lowerenvname}/zabbix/custom/* /etc/zabbix/zabbix_agentd.d/


  ZABIX_NAME=${camelEnvName}_${lowerenvtype}${AMI_LAUNCH_BASE}
  echo "ZABIX_NAME = " ${ZABIX_NAME}
  sed -i "s/changeToHost/${ZABIX_NAME}/g" /etc/zabbix/zabbix_agentd.conf
  rm /tmp/zabbix_agentd.pid
  chkconfig --add zabbix-agent
  chkconfig zabbix-agent on --level 3
  service zabbix-agent start

  #----------------------------------------------------- java -----------------------------------------------------------#
  if aws s3 cp s3://company-ci-files/jdk-${JAVA_VERSION}-linux-x64.tar.gz ${homedir}/jdk-${JAVA_VERSION}-linux-x64.tar.gz; then
  #if wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/${JAVA_VERSION}-b14/jdk-${JAVA_VERSION}-linux-x64.tar.gz"; then
      tar -zxvf ${homedir}/jdk-${JAVA_VERSION}-linux-x64.tar.gz -C /opt
      rm ${homedir}/jdk-${JAVA_VERSION}-linux-x64.tar.gz
      cd /opt/jdk1.8.0_${JAVA_MINOR}
      update-alternatives --install /usr/bin/java java /opt/java/jdk1.8.${JAVA_MINOR}/bin/java 100
      sudo alternatives --set java /opt/java/jdk1.8.111/bin/java
      export JAVA_HOME=/opt/java/jdk1.8.${JAVA_MINOR}/
      export JRE_HOME=/opt/java/jdk1.8.${JAVA_MINOR}/jre
      rm /opt/jdk
      ln -s /opt/jdk1.8.0_${JAVA_MINOR} /opt/jdk

      echo 'PATH=/opt/jdk/bin:$PATH' >> ${homedir}/.bash_profile
      echo "export PATH" >> ${homedir}/.bash_profile
      source ${homedir}/.bash_profile
  else
      error_exit "Cannot get java!  Aborting."
  fi

  #------------------------------------------------- company ---------------------------------------------------------#
  setupAppDir () {
      mkdir $1
      mkdir $1/logs
      mkdir $1/config
      mkdir $1/releases
      cp ${homedir}/ops/global/system/deploy-from-nexus.sh $1/deploy-from-nexus.sh
  }

  setupAppDir ${homedir}/deploy

  if [ "$lowerenvname" == "analytics" ]; then
      touch ${homedir}/deploy/config/application-${lowerenvtype}.properties
      echo -e "analytics.machine.instance:" ${AMI_LAUNCH_INDEX} >> ${homedir}/deploy/config/application-${lowerenvtype}.properties

      #for device manger, fix tcp limit
      cp ${homedir}/ops/${lowerenvname}/system/limits.conf /etc/security/limits.conf
      ulimit -Sn 50000
      ulimit -Hn 50000
  fi

  if [ "$lowerenvname" == "api" ]; then
      #for kafka, increase tcp limit
      cp ${homedir}/ops/${lowerenvname}/system/limits.conf /etc/security/limits.conf
      ulimit -Sn 10000
      ulimit -Hn 10000
  fi

  APP_VERSION=`curl -s https://s3-us-west-2.amazonaws.com/company-ci-files/app_versions/${lowerenvtype}_${lowerenvname}_version.txt`
  echo APP_VERSION - $APP_VERSION
  cd ${homedir}/deploy && ./deploy-from-nexus.sh ${APP_VERSION} company-${lowerenvname} ${lowerenvname} false

  mkdir /var/log/company
  chown -R company:company /var/log/company
  cp ${homedir}/ops/${lowerenvname}/scripts/*.* ${homedir}/

  #----------------------------------------------------- system ---------------------------------------------------------#
  rm -f /etc/supervisord.conf
  cp ${homedir}/ops/${lowerenvname}/system/supervisord.conf /etc/supervisord.conf
  case ${lowerenvtype} in
    dev)
    envtypeProfile=dev
    ;;
    stg)
    envtypeProfile=staging
    ;;
    load)
    envtypeProfile=load
    ;;
    prd)
    envtypeProfile=prod-us
    ;;
  esac
  sed -i "s/changeProfile/${envtypeProfile}/g" /etc/supervisord.conf
  sed -i "s|monitorDir|${monitordir}|g" /etc/supervisord.conf

  #removeLines () {
  #    sed -i "/\[$1]/,/;$1/d" /etc/supervisord.conf
  #}

  #if (( $AMI_LAUNCH_INDEX > 0 )); then
  #    echo "------------------------------------------------ clean supervisord.conf ---------------------------------------------------------"
  #    removeLines "program:zookeeper"
  #    removeLines "program:kafka"
  #    removeLines "program:trifecta"
  #    removeLines "program:device-manager"
  #fi
  if [[ -f /etc/init.d/supervisord.sh ]]; then
    rm /etc/init.d/supervisord.sh
  fi
  cp ${homedir}/ops/global/system/supervisord.sh /etc/init.d/supervisord
  chmod +x /etc/init.d/supervisord
  chkconfig --add supervisord
  chkconfig supervisord on --level 3
  touch /var/log/supervisord.log
  chown company:company /var/log/supervisord.log
  runuser -l company -c "supervisord"

  #import crontab config
  runuser -l company -c "crontab ${homedir}/ops/${lowerenvname}/system/crontab.bak"
  runuser -l company -c "crontab -l"

  # Update custom motd
  sudo cp ${homedir}/ops/global/system/80-custom-motd /etc/update-motd.d/
  if [[ $envname = "Api" && $AMI_LAUNCH_BASE = "1" || $AMI_LAUNCH_BASE = "2" ]]; then
    sudo sed -i 's!^fi!fi \nPubIp=\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4) \necho "Trifecta UI: http://${PubIp}:9003/#/inspect?mode=zookeeper"!g' /etc/update-motd.d/80-custom-motd
  fi
  sudo /usr/sbin/update-motd
  #------------------------------------------------ Setup specific ------------------------------------------------------#
  # add redis to dev batch
  if [ "$lowerenvtype" == "dev" ] && [ "$lowerenvname" == "batch" ]; then
      #install redis
      echo "installing redis"
      rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
      yum -y --enablerepo=remi,remi-test install redis
      sed -i '/bind/s/^/#/g' /etc/redis.conf
      sed -i "s/# requirepass foobared/requirepass angeldev/g" /etc/redis.conf
      chkconfig --add redis
      chkconfig --level 345 redis on

      service redis start
  fi
  # add device manager to analytics
  if [ "$lowerenvname" == "analytics" ]; then
      mkdir /var/log/device-manager
      chown -R company:company /var/log/device-manager
      setupAppDir ${homedir}/device-manager
      DM_APP_VERSION=`curl https://s3-us-west-2.amazonaws.com/company-ci-files/app_versions/${lowerenvtype}_device-manager_version.txt`
      echo DM_APP_VERSION - $DM_APP_VERSION
      cd ${homedir}/device-manager
      ${homedir}/device-manager/deploy-from-nexus.sh ${DM_APP_VERSION} device-manager device-manager false
  fi

  if [ "$lowerenvname" == "api" ]; then
      #aws elb register-instances-with-load-balancer --load-balancer-name ${elbname} --instances $INSTANCE_ID --region $region
      aws elbv2 register-targets --target-group-arn $targetgrouparn --targets Id=$INSTANCE_ID
  fi

  touch ${homedir}/deploy/config/application-${lowerenvtype}.properties
  #---------------------------------------------------- Cleanup ---------------------------------------------------------#
  chown -R company:company ${homedir}

  #do not remove, it is needed for machine reboot
  #rm -rf ${homedir}/ops

  touch ${homedir}/allok.txt
  chown company:company ${homedir}/allok.txt

  echo -e "BUILD:\\t" `cat ${homedir}/ops/build.txt` >> ${homedir}/allok.txt
  echo -e "TIME:\\t" ${SECONDS} >> ${homedir}/allok.txt
  echo -e "LIQUIBASE_VERSION:\\t" ${LIQUIBASE_VERSION} >> ${homedir}/allok.txt
  echo -e "JAVA_VERSION:\\t" ${JAVA_VERSION} >> ${homedir}/allok.txt
  echo -e "KAFKA_VERSION:\\t" ${KAFKA_VERSION} >> ${homedir}/allok.txt
  echo -e "CASSANDRA_VERSION:\\t" ${CASSANDRA_VERSION} >> ${homedir}/allok.txt
  echo -e "KAFKA_ZOOKEEPER_MANAGER_VERSION:\\t" ${KAFKA_ZOOKEEPER_MANAGER_VERSION} >> ${homedir}/allok.txt
  echo -e "TRIFECTA_VERSION:\\t" ${TRIFECTA_VERSION} >> ${homedir}/allok.txt
  echo -e "INSTANCE_ID:\\t" ${INSTANCE_ID} >> ${homedir}/allok.txt
  echo -e "APP_VERSION:\\t" ${APP_VERSION} >> ${homedir}/allok.txt
  echo "************************" >> ${homedir}/allok.txt
  echo -e "elbname:\\t" ${elbname} >> ${homedir}/allok.txt
  #echo -e "elasticip:\\t" ${elasticip} >> ${homedir}/allok.txt
  echo -e "currentDns:\\t" ${currentDns} >> ${homedir}/allok.txt
  echo -e "ASSIGNED_IP:\\t" ${ASSIGNED_IP} >> ${homedir}/allok.txt
  echo -e "localip:\\t" ${localip} >> ${homedir}/allok.txt
  echo -e "AMI_LAUNCH_INDEX:\\t" ${AMI_LAUNCH_INDEX} >> ${homedir}/allok.txt
  echo "************************" >> ${homedir}/allok.txt
  echo -e "apiIPa:\\t" ${apiIPa} >> ${homedir}/allok.txt
  echo -e "apiIPb:\\t" ${apiIPb} >> ${homedir}/allok.txt
  echo -e "analyticsIPa:\\t" ${analyticsIPa} >> ${homedir}/allok.txt
  #echo -e "analyticsIPb:\\t" ${analyticsIPb} >> ${homedir}/allok.txt
  echo -e "batchIP:\\t" ${batchIP} >> ${homedir}/allok.txt

  echo -e "ulimit soft:\\t" $(ulimit -Sn) >> ${homedir}/allok.txt
  echo -e "ulimit hard:\\t" $(ulimit -Hn) >> ${homedir}/allok.txt

  # Update packages
  yum -y install mysql mlocate tree telnet
  yum update -y
  yum clean all
  sudo updatedb
fi

if [[ $envname = "Cassandra" ]]; then
  echo "envname: $envname"
  echo "envtype: $envtype"
  echo "stack name: $stackname"
  echo "vpcid: $vpcid"
  echo "AMI_LAUNCH_INDEX: $AMI_LAUNCH_INDEX"
  echo "AMI_LAUNCH_BASE: $AMI_LAUNCH_BASE"

  # Cassandra related stuff
  sudo cp ${homedir}/ops/global/system/70-custom-motd /etc/update-motd.d/
  run-parts /etc/update-motd.d/ &>/dev/null
  chown -R bitnami:bitnami ${homedir}

  cassandraYaml="${homedir}/stack/cassandra/conf/cassandra.yaml"

  echo """
data_file_directories:
# - /opt/bitnami/cassandra/data/data
 - /data/data
  """ >> $cassandraYaml

  if [[ $envtype == "Prd" ]]; then
    sed -i 's/commitlog_segment_size_in_mb.*/commitlog_segment_size_in_mb: 64/g' $cassandraYaml | grep commitlog_segment_size_in_mb
    sed -i 's/batch_size_warn_threshold_in_kb.*/batch_size_warn_threshold_in_kb: 10/g' $cassandraYaml | grep batch_size_warn_threshold_in_kb
  fi

  echo "Attaching EBS disk, applying filesystem and mounting to /data"
  mkdir /data
  mkfs.ext4 /dev/xvdf
  sudo sed -i 's/^\/dev\/xvd.*/\/dev\/xvdf       \/data   auto    defaults,nobootwait,comment=cloudconfig 0      2/g' /etc/fstab
  mount -a
  chown -R cassandra:cassandra /data

  sudo -Eu bitnami bash
  set -o verbose

  echo homedir - ${homedir}
  echo lowerenvtype - ${lowerenvtype}
  echo envtype - ${envtype}

  PUBLIC_IP=`curl http://169.254.169.254/latest/meta-data/public-ipv4`

  if [[ "$cluster" = "true" ]]; then
    sudo sed -i "s|cluster_name: 'Test Cluster'|cluster_name: '${lowerenvtype}-company-${BUILD_NUMBER}'|g" /opt/bitnami/cassandra/conf/cassandra.yaml
    sudo sed -i "s|seeds: \"127.0.0.1\"|seeds: \"${localip}\"|g" /opt/bitnami/cassandra/conf/cassandra.yaml
    sudo sed -i "s|listen_address: localhost|listen_address: ${localip}|g" /opt/bitnami/cassandra/conf/cassandra.yaml
    #sudo sed -i "s|# broadcast_address: 1.2.3.4|broadcast_address: ${PUBLIC_IP}|g" /opt/bitnami/cassandra/conf/cassandra.yaml
    sudo sed -i "s|endpoint_snitch: SimpleSnitch|endpoint_snitch: Ec2Snitch|g" /opt/bitnami/cassandra/conf/cassandra.yaml
    echo "cluster configured"
  fi

  sudo rm -rf /opt/bitnami/cassandra/data/*

  if [[ $AMI_LAUNCH_BASE == 2 || $AMI_LAUNCH_BASE == 4 || $numberofmachines == 1 ]]; then
    #setup password
    echo "remove security"
    sudo sed -i "s|authenticator: PasswordAuthenticator|authenticator: AllowAllAuthenticator|g" /opt/bitnami/cassandra/conf/cassandra.yaml
    sudo sed -i "s|authorizer: CassandraAuthorizer|authorizer: AllowAllAuthorizer|g" /opt/bitnami/cassandra/conf/cassandra.yaml
    sudo /opt/bitnami/ctlscript.sh stop cassandra
    sudo rm -rf /opt/bitnami/cassandra/data/*
    sudo /opt/bitnami/ctlscript.sh restart cassandra

    echo "reset defualt password"
    sudo sed -i "s|authenticator: AllowAllAuthenticator|authenticator: PasswordAuthenticator|g" /opt/bitnami/cassandra/conf/cassandra.yaml
    sudo sed -i "s|authorizer: AllowAllAuthorizer|authorizer: CassandraAuthorizer|g" /opt/bitnami/cassandra/conf/cassandra.yaml
    sudo /opt/bitnami/ctlscript.sh restart cassandra
    sleep 10

    #replicate system_auth table to all nodes
    #cqlsh -u cassandra -p cassandra -e "ALTER KEYSPACE system_auth WITH REPLICATION = { 'class' : 'SimpleStrategy', 'replication_factor' : 3 };"
  else
      echo "not seed machine"
  fi
fi

if [[ "$envname" = "Bastion" ]]; then
  pip install awscli --upgrade
  pip install awscli --upgrade --user

  # Associate vpc to route53 zone
  defaultHostedZoneId="Z1ZOGSXD2823ZV"
  defaultVpcId="vpc-20e2094b"
  defaultVpcRouteTable="rtb-3fe20954"
  oregonregion="us-west-2"
  opsSG="sg-667e9c02"
  echo "Associating VPC with hosted zone..."
  aws route53 associate-vpc-with-hosted-zone --hosted-zone-id $defaultHostedZoneId --vpc VPCRegion=$region,VPCId=$vpcid
  if [[ "$region" = "us-west-2" ]]; then
    aws ec2 modify-vpc-peering-connection-options --vpc-peering-connection-id $vpcpeeringid --requester-peering-connection-options AllowDnsResolutionFromRemoteVpc=true --region $oregonregion
    aws ec2 modify-vpc-peering-connection-options --vpc-peering-connection-id $vpcpeeringid --accepter-peering-connection-options AllowDnsResolutionFromRemoteVpc=true --region $oregonregion
  else
    echo "Creating VPC peering with Oregon's VPC"
    PeeringConnectionId=$(aws ec2 create-vpc-peering-connection --peer-owner-id AWS_ACCOUNT_ID --peer-vpc-id $defaultVpcId --vpc-id $vpcid --peer-region $oregonregion --region $region | grep VpcPeeringConnectionId | awk '{print $2}' | tr -d '\"\|,')
    sleep 10
    aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $PeeringConnectionId --region $oregonregion
    echo "Creating routes to management VPC"
    aws ec2 create-route --destination-cidr-block 172.31.0.0/16 --route-table-id $vpcroutetable --vpc-peering-connection-id $PeeringConnectionId --region $region
    if $(aws ec2 describe-route-tables --route-table-id $defaultVpcRouteTable --region $oregonregion | grep -q $vpccidr); then
      aws ec2 replace-route --destination-cidr-block $vpccidr --route-table-id $defaultVpcRouteTable --vpc-peering-connection-id $PeeringConnectionId --region $oregonregion
    else
      aws ec2 create-route --destination-cidr-block $vpccidr --route-table-id $defaultVpcRouteTable --vpc-peering-connection-id $PeeringConnectionId --region $oregonregion
    fi
    #echo "Adding security group rule to allow traffic between OPS servers and the new stack"
    #aws ec2 authorize-security-group-ingress --group-id $opsSG --ip-permissions '[{"IpProtocol": "-1", "IpRanges": [{"CidrIp": "$vpccidr"}]}]' --region us-west-2
    #aws ec2 authorize-security-group-ingress --group-id $asgpilotsgid --ip-permissions '[{"IpProtocol": "-1", "IpRanges": [{"CidrIp": "172.31.0.0/16"}]}]' --region $region
    #aws ec2 authorize-security-group-ingress --group-id $bastionsgid --ip-permissions '[{"IpProtocol": "-1", "IpRanges": [{"CidrIp": "172.31.0.0/16"}]}]' --region $region

  fi
  #----------------------------------------------------- java -----------------------------------------------------------#
  if aws s3 cp s3://company-ci-files/jdk-${JAVA_VERSION}-linux-x64.tar.gz ${homedir}/jdk-${JAVA_VERSION}-linux-x64.tar.gz; then
  #if wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/${JAVA_VERSION}-b14/jdk-${JAVA_VERSION}-linux-x64.tar.gz"; then

      tar -zxvf ${homedir}/jdk-${JAVA_VERSION}-linux-x64.tar.gz -C /opt
      rm ${homedir}/jdk-${JAVA_VERSION}-linux-x64.tar.gz
      cd /opt/jdk1.8.0_${JAVA_MINOR}
      update-alternatives --install /usr/bin/java java /opt/java/jdk1.8.${JAVA_MINOR}/bin/java 100
      alternatives --set java /opt/java/jdk1.8.${JAVA_MINOR}/bin/java
      export JAVA_HOME=/opt/java/jdk1.8.${JAVA_MINOR}/
      export JRE_HOME=/opt/java/jdk1.8.${JAVA_MINOR}/jre
      rm -rf /opt/jdk
      ln -s /opt/jdk1.8.0_${JAVA_MINOR} /opt/jdk

      echo 'export PATH=/opt/jdk/bin:$PATH' >> ${homedir}/.bash_profile
      source ${homedir}/.bash_profile
  else
      error_exit "Cannot get java!  Aborting."
  fi

  sudo -Eu ec2-user bash
  set -o verbose
  tool="restorer"
  log echo "DEBUG"
  log echo "homedir : ${homedir}"
  log echo "tool : ${tool}"
  log echo "lowerenvtype : ${lowerenvtype}"
  cd ${homedir}
  aws s3 cp s3://company-ci-files/${tool}/${lowerenvtype}_${tool}.zip .
  if [[ $? -eq "0" ]]; then
    echo "${tool} downloaded successfully!"
    unzip ${lowerenvtype}_${tool}.zip
    cd ${tool} && ./restore.sh ${lowerenvtype} ${lowerenvtype}-cassandra1.${fqdn} &
  else
    echo "Unable to download ${lowerenvtype}_${tool}.zip from S3!"
    exit 1
  fi
  if [[ $? -eq "0" ]]; then
    echo "File was downloaded, unpacked and ran successfully!"
    rm -f ${homedir}/${tool}/${lowerenvtype}_${tool}
  fi
fi

echo FINISH
