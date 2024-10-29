#!/bin/bash
# This script is a work in progress, it is not complete and should not be used in production.
# The script is intended to be used as a reference for creating a Kubernetes cluster on AWS.
# The script is based on the book "Kubernetes Up & Running" by Kelsey Hightower, Brendan Burns, and Joe Beda.
# This script is 
# This script has been written by Itai Ganot 2024.

export AWS_REGION=il-central-1
export AWS_PAGER=""
CLUSTER_NAME=kubernetes
ETCD_VERSION=v3.5.16
k8s_version=v1.31.1
containerd_version=1.7.22
cni_plugins_version=v1.5.1
runc_version=v1.2.0-rc.3
number_of_controllers=1
number_of_workers=2
controller_instance_type=t2.medium
worker_instance_type=t3.small
sg_dest_ip="X.X.X.X/32"

# VPC Creation
echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --output text --query 'Vpc.VpcId')
aws ec2 create-tags --resources ${VPC_ID} --tags Key=Name,Value=$CLUSTER_NAME
aws ec2 modify-vpc-attribute --vpc-id ${VPC_ID} --enable-dns-support '{"Value": true}'
aws ec2 modify-vpc-attribute --vpc-id ${VPC_ID} --enable-dns-hostnames '{"Value": true}'

# Subnets Creation
echo "Creating Subnets..."
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id ${VPC_ID} \
  --cidr-block 10.0.1.0/24 \
  --output text --query 'Subnet.SubnetId')
aws ec2 create-tags --resources ${SUBNET_ID} --tags Key=Name,Value=$CLUSTER_NAME

# Internet Gateway Creation
echo "Creating Internet Gateway..."
INTERNET_GATEWAY_ID=$(aws ec2 create-internet-gateway --output text --query 'InternetGateway.InternetGatewayId')
aws ec2 create-tags --resources ${INTERNET_GATEWAY_ID} --tags Key=Name,Value=$CLUSTER_NAME
aws ec2 attach-internet-gateway --internet-gateway-id ${INTERNET_GATEWAY_ID} --vpc-id ${VPC_ID}

# Route Table Creation
echo "Creating Route table..."
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id ${VPC_ID} --output text --query 'RouteTable.RouteTableId')
aws ec2 create-tags --resources ${ROUTE_TABLE_ID} --tags Key=Name,Value=$CLUSTER_NAME
aws ec2 associate-route-table --route-table-id ${ROUTE_TABLE_ID} --subnet-id ${SUBNET_ID}
aws ec2 create-route --route-table-id ${ROUTE_TABLE_ID} --destination-cidr-block 0.0.0.0/0 --gateway-id ${INTERNET_GATEWAY_ID}

# Security Groups Creation
echo "Creating Security Groups..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
  --group-name $CLUSTER_NAME \
  --description "$CLUSTER_NAME security group" \
  --vpc-id ${VPC_ID} \
  --output text --query 'GroupId')
aws ec2 create-tags --resources ${SECURITY_GROUP_ID} --tags Key=Name,Value=$CLUSTER_NAME
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol all --cidr 10.0.0.0/16
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol all --cidr 10.200.0.0/16
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port 22 --cidr $sg_dest_ip
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port 6443 --cidr $sg_dest_ip
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port 443 --cidr $sg_dest_ip
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol icmp --port -1 --cidr $sg_dest_ip

# Kubernetes Public Access - Create a Network Load Balancer
echo "Creating NLB..."
LOAD_BALANCER_ARN=$(aws elbv2 create-load-balancer \
--name $CLUSTER_NAME \
--subnets ${SUBNET_ID} \
--scheme internet-facing \
--type network \
--output text --query 'LoadBalancers[].LoadBalancerArn')
TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
--name $CLUSTER_NAME \
--protocol TCP \
--port 6443 \
--vpc-id ${VPC_ID} \
--target-type ip \
--output text --query 'TargetGroups[].TargetGroupArn')
aws elbv2 register-targets --target-group-arn ${TARGET_GROUP_ARN} --targets Id=10.0.1.1{0,1,2}
aws elbv2 create-listener \
--load-balancer-arn ${LOAD_BALANCER_ARN} \
--protocol TCP \
--port 443 \
--default-actions Type=forward,TargetGroupArn=${TARGET_GROUP_ARN} \
--output text --query 'Listeners[].ListenerArn'

KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns ${LOAD_BALANCER_ARN} \
  --output text --query 'LoadBalancers[].DNSName')

# Compute instances
## Instance Image - Ubuntu 20.04
echo "Getting Instance Image..."
IMAGE_ID=$(aws ec2 describe-images --owners 099720109477 \
  --output json \
  --filters \
  'Name=root-device-type,Values=ebs' \
  'Name=architecture,Values=x86_64' \
  'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*' \
  | jq -r '.Images|sort_by(.Name)[-1]|.ImageId')

## SSH Keypair Creation
echo "Creating ssh keypair..."
aws ec2 create-key-pair --key-name kubernetes --output text --query 'KeyMaterial' > kubernetes.id_rsa
chmod 600 kubernetes.id_rsa

## Kubernetes Controllers Creation
echo "Creating k8s controllers..."
for ((i=0;i<${number_of_controllers};i+=1)); do
  instance_id=$(aws ec2 run-instances \
    --associate-public-ip-address \
    --image-id ${IMAGE_ID} \
    --count 1 \
    --key-name kubernetes \
    --security-group-ids ${SECURITY_GROUP_ID} \
    --instance-type ${controller_instance_type} \
    --private-ip-address 10.0.1.1${i} \
    --user-data "name=controller-${i}" \
    --subnet-id ${SUBNET_ID} \
    --block-device-mappings='{"DeviceName": "/dev/sda1", "Ebs": { "VolumeSize": 20 }, "NoDevice": "" }' \
    --output text --query 'Instances[].InstanceId')
  aws ec2 modify-instance-attribute --instance-id ${instance_id} --no-source-dest-check
  aws ec2 create-tags --resources ${instance_id} --tags Key=Name,Value=controller-${i} Key=ClusterName,Value=${CLUSTER_NAME}
  echo "controller-${i} created "
done

## Kubernetes Workers Creation
echo "Creating k8s workers..."
for ((i=0;i<${number_of_workers};i+=1)); do
  instance_id=$(aws ec2 run-instances \
    --associate-public-ip-address \
    --image-id ${IMAGE_ID} \
    --count 1 \
    --key-name kubernetes \
    --security-group-ids ${SECURITY_GROUP_ID} \
    --instance-type ${worker_instance_type} \
    --private-ip-address 10.0.1.2${i} \
    --user-data "name=worker-${i}|pod-cidr=10.200.${i}.0/24" \
    --subnet-id ${SUBNET_ID} \
    --block-device-mappings='{"DeviceName": "/dev/sda1", "Ebs": { "VolumeSize": 20 }, "NoDevice": "" }' \
    --output text --query 'Instances[].InstanceId')
  aws ec2 modify-instance-attribute --instance-id ${instance_id} --no-source-dest-check
  aws ec2 create-tags --resources ${instance_id} --tags Key=Name,Value=worker-${i} Key=ClusterName,Value=${CLUSTER_NAME}
  echo "worker-${i} created"
done

# Sleeping until instances are fully created
which pv &>/dev/null || sudo apt-get install -y pv
echo "Sleeping 2 minutes until instances are fully created..."
sleep 120 | pv -t

# # Certificate Authority - CA Certs Creation
# echo "Generating CA certs..."
# cat > ca-config.json <<EOF
# {
#   "signing": {
#     "default": {
#       "expiry": "8760h"
#     },
#     "profiles": {
#       "kubernetes": {
#         "usages": ["signing", "key encipherment", "server auth", "client auth"],
#         "expiry": "8760h"
#       }
#     }
#   }
# }
# EOF

# cat > ca-csr.json <<EOF
# {
#   "CN": "Kubernetes",
#   "key": {
#     "algo": "rsa",
#     "size": 2048
#   },
#   "names": [
#     {
#       "C": "IL",
#       "L": "TEL-AVIV",
#       "O": "Kubernetes",
#       "OU": "Kubernetes",
#       "ST": "Tel-Aviv"
#     }
#   ]
# }
# EOF

# cfssl gencert -initca ca-csr.json | cfssljson -bare ca

# # Client and Server Certificates
# ## The Kubernetes Admin Client Cert
# echo "Generating Admin Client cert..."
# cat > admin-csr.json <<EOF
# {
#   "CN": "admin",
#   "key": {
#     "algo": "rsa",
#     "size": 2048
#   },
#   "names": [
#     {
#       "C": "IL",
#       "L": "TEL-AVIV",
#       "O": "system:masters",
#       "OU": "Kubernetes",
#       "ST": "Tel-Aviv"
#     }
#   ]
# }
# EOF

# cfssl gencert \
#   -ca=ca.pem \
#   -ca-key=ca-key.pem \
#   -config=ca-config.json \
#   -profile=kubernetes \
#   admin-csr.json | cfssljson -bare admin

# # The Kubelet Client Certificates
# echo "Generating k8s client certs..."
# for ((i=0;i<${number_of_workers};i+=1)); do
#   instance="worker-${i}"
#   instance_hostname="ip-10-0-1-2${i}"
#   cat > ${instance}-csr.json <<EOF
# {
#   "CN": "system:node:${instance_hostname}",
#   "key": {
#     "algo": "rsa",
#     "size": 2048
#   },
#   "names": [
#     {
#       "C": "IL",
#       "L": "TEL-AVIV",
#       "O": "system:nodes",
#       "OU": "Kubernetes",
#       "ST": "Tel-Aviv"
#     }
#   ]
# }
# EOF

#   external_ip=$(aws ec2 describe-instances --filters \
#     "Name=tag:Name,Values=${instance}" \
#     "Name=instance-state-name,Values=running" \
#     --output text --query 'Reservations[].Instances[].PublicIpAddress')

#   internal_ip=$(aws ec2 describe-instances --filters \
#     "Name=tag:Name,Values=${instance}" \
#     "Name=instance-state-name,Values=running" \
#     --output text --query 'Reservations[].Instances[].PrivateIpAddress')

#   cfssl gencert \
#     -ca=ca.pem \
#     -ca-key=ca-key.pem \
#     -config=ca-config.json \
#     -hostname=${instance_hostname},${external_ip},${internal_ip} \
#     -profile=kubernetes \
#     worker-${i}-csr.json | cfssljson -bare worker-${i}
# done

# ## The Controller Manager Client Certificate
# echo "Generating kube-controller-manager cert..."
# cat > kube-controller-manager-csr.json <<EOF
# {
#   "CN": "system:kube-controller-manager",
#   "key": {
#     "algo": "rsa",
#     "size": 2048
#   },
#   "names": [
#     {
#       "C": "IL",
#       "L": "TEL-AVIV",
#       "O": "system:kube-controller-manager",
#       "OU": "Kubernetes",
#       "ST": "Tel-Aviv"
#     }
#   ]
# }
# EOF

# cfssl gencert \
#   -ca=ca.pem \
#   -ca-key=ca-key.pem \
#   -config=ca-config.json \
#   -profile=kubernetes \
#   kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

# ## The Kube Proxy Client Certificate
# echo "Generating kube-proxy client cert..."
# cat > kube-proxy-csr.json <<EOF
# {
#   "CN": "system:kube-proxy",
#   "key": {
#     "algo": "rsa",
#     "size": 2048
#   },
#   "names": [
#     {
#       "C": "IL",
#       "L": "TEL-AVIV",
#       "O": "system:node-proxier",
#       "OU": "Kubernetes",
#       "ST": "Tel-Aviv"
#     }
#   ]
# }
# EOF

# cfssl gencert \
#   -ca=ca.pem \
#   -ca-key=ca-key.pem \
#   -config=ca-config.json \
#   -profile=kubernetes \
#   kube-proxy-csr.json | cfssljson -bare kube-proxy

# ## The Kubernetes Scheduler Client Certificate
# echo "Generating kube-scheduler client cert..."
# cat > kube-scheduler-csr.json <<EOF
# {
#   "CN": "system:kube-scheduler",
#   "key": {
#     "algo": "rsa",
#     "size": 2048
#   },
#   "names": [
#     {
#       "C": "IL",
#       "L": "TEL-AVIV",
#       "O": "system:kube-scheduler",
#       "OU": "Kubernetes",
#       "ST": "Tel-Aviv"
#     }
#   ]
# }
# EOF

# cfssl gencert \
#   -ca=ca.pem \
#   -ca-key=ca-key.pem \
#   -config=ca-config.json \
#   -profile=kubernetes \
#   kube-scheduler-csr.json | cfssljson -bare kube-scheduler

# ## The Kubernetes API Server Certificate
# echo "Generating kube-apiserver cert..."
# KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

# cat > kubernetes-csr.json <<EOF
# {
#   "CN": "kubernetes",
#   "key": {
#     "algo": "rsa",
#     "size": 2048
#   },
#   "names": [
#     {
#       "C": "IL",
#       "L": "TEL-AVIV",
#       "O": "Kubernetes",
#       "OU": "Kubernetes",
#       "ST": "Tel-Aviv"
#     }
#   ]
# }
# EOF

# cfssl gencert \
#   -ca=ca.pem \
#   -ca-key=ca-key.pem \
#   -config=ca-config.json \
#   -hostname=10.32.0.1,10.0.1.10,10.0.1.11,10.0.1.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
#   -profile=kubernetes \
#   kubernetes-csr.json | cfssljson -bare kubernetes

# ## The Service Account Key Pair
# echo "Generating SA keypair..."
# cat > service-account-csr.json <<EOF
# {
#   "CN": "service-accounts",
#   "key": {
#     "algo": "rsa",
#     "size": 2048
#   },
#   "names": [
#     {
#       "C": "IL",
#       "L": "TEL-AVIV",
#       "O": "Kubernetes",
#       "OU": "Kubernetes",
#       "ST": "Tel-Aviv"
#     }
#   ]
# }
# EOF

# cfssl gencert \
#   -ca=ca.pem \
#   -ca-key=ca-key.pem \
#   -config=ca-config.json \
#   -profile=kubernetes \
#   service-account-csr.json | cfssljson -bare service-account

# # Distribution of Client and Server Certificates
# echo "Distributing client and server certs..."
# for ((i=0;i<${number_of_workers};i+=1)); do
#   instance="worker-${i}"
#   external_ip=$(aws ec2 describe-instances --filters \
#     "Name=tag:Name,Values=${instance}" \
#     "Name=instance-state-name,Values=running" \
#     --output text --query 'Reservations[].Instances[].PublicIpAddress')

#   scp -i kubernetes.id_rsa ca.pem ${instance}-key.pem ${instance}.pem ubuntu@${external_ip}:~/
# done

# for ((i=0;i<${number_of_controllers};i+=1)); do
#   instance="controller-${i}"
#   external_ip=$(aws ec2 describe-instances --filters \
#     "Name=tag:Name,Values=${instance}" \
#     "Name=instance-state-name,Values=running" \
#     --output text --query 'Reservations[].Instances[].PublicIpAddress')

#   scp -i kubernetes.id_rsa ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem service-account-key.pem service-account.pem ubuntu@${external_ip}:~/
# done

# # Kubernetes Public DNS Address
# KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers \
#   --load-balancer-arns ${LOAD_BALANCER_ARN} \
#   --output text --query 'LoadBalancers[0].DNSName')

# # Client Authentication Configs
# ## The kubelet Kubernetes Configuration File
# echo "Configuring kubelet configuration files..."
# for ((i=0;i<${number_of_workers};i+=1)); do
#   instance="worker-${i}"
#   kubectl config set-cluster $CLUSTER_NAME \
#     --certificate-authority=ca.pem \
#     --embed-certs=true \
#     --server=https://${KUBERNETES_PUBLIC_ADDRESS}:443 \
#     --kubeconfig=${instance}.kubeconfig

#   kubectl config set-credentials system:node:${instance} \
#     --client-certificate=${instance}.pem \
#     --client-key=${instance}-key.pem \
#     --embed-certs=true \
#     --kubeconfig=${instance}.kubeconfig

#   kubectl config set-context default \
#     --cluster=kubernetes \
#     --user=system:node:${instance} \
#     --kubeconfig=${instance}.kubeconfig

#   kubectl config use-context default --kubeconfig=${instance}.kubeconfig
# done

# kubectl config set-cluster $CLUSTER_NAME \
#   --certificate-authority=ca.pem \
#   --embed-certs=true \
#   --server=https://${KUBERNETES_PUBLIC_ADDRESS}:443 \
#   --kubeconfig=kube-proxy.kubeconfig

# kubectl config set-credentials system:kube-proxy \
#   --client-certificate=kube-proxy.pem \
#   --client-key=kube-proxy-key.pem \
#   --embed-certs=true \
#   --kubeconfig=kube-proxy.kubeconfig

# kubectl config set-context default \
#   --cluster=$CLUSTER_NAME \
#   --user=system:kube-proxy \
#   --kubeconfig=kube-proxy.kubeconfig

# kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

# ## The kube-controller-manager Kubernetes Configuration File
# echo "Configuring kube-controller-mamager configuration file..."
# kubectl config set-cluster $CLUSTER_NAME \
#   --certificate-authority=ca.pem \
#   --embed-certs=true \
#   --server=https://127.0.0.1:6443 \
#   --kubeconfig=kube-controller-manager.kubeconfig

# kubectl config set-credentials system:kube-controller-manager \
#   --client-certificate=kube-controller-manager.pem \
#   --client-key=kube-controller-manager-key.pem \
#   --embed-certs=true \
#   --kubeconfig=kube-controller-manager.kubeconfig

# kubectl config set-context default \
#   --cluster=$CLUSTER_NAME \
#   --user=system:kube-controller-manager \
#   --kubeconfig=kube-controller-manager.kubeconfig

# kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

# ## The kube-scheduler Kubernetes Configuration File
# echo "Configuring kube-schedule configuration file..."
# kubectl config set-cluster $CLUSTER_NAME \
#   --certificate-authority=ca.pem \
#   --embed-certs=true \
#   --server=https://127.0.0.1:6443 \
#   --kubeconfig=kube-scheduler.kubeconfig

# kubectl config set-credentials system:kube-scheduler \
#   --client-certificate=kube-scheduler.pem \
#   --client-key=kube-scheduler-key.pem \
#   --embed-certs=true \
#   --kubeconfig=kube-scheduler.kubeconfig

# kubectl config set-context default \
#   --cluster=$CLUSTER_NAME \
#   --user=system:kube-scheduler \
#   --kubeconfig=kube-scheduler.kubeconfig

# kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

# ## The admin Kubernetes Configuration File
# echo "Configuring k8s configuration file..."
# kubectl config set-cluster $CLUSTER_NAME \
#   --certificate-authority=ca.pem \
#   --embed-certs=true \
#   --server=https://127.0.0.1:6443 \
#   --kubeconfig=admin.kubeconfig

# kubectl config set-credentials admin \
#   --client-certificate=admin.pem \
#   --client-key=admin-key.pem \
#   --embed-certs=true \
#   --kubeconfig=admin.kubeconfig

# kubectl config set-context default \
#   --cluster=$CLUSTER_NAME \
#   --user=admin \
#   --kubeconfig=admin.kubeconfig

# kubectl config use-context default --kubeconfig=admin.kubeconfig

# # Distribute the Kubernetes Configuration Files
# echo "Distributing k8s configuration files..."
# for ((i=0;i<${number_of_workers};i+=1)); do
#   instance="worker-${i}"
#   external_ip=$(aws ec2 describe-instances --filters \
#     "Name=tag:Name,Values=${instance}" \
#     "Name=instance-state-name,Values=running" \
#     --output text --query 'Reservations[].Instances[].PublicIpAddress')

#   scp -i kubernetes.id_rsa \
#     ${instance}.kubeconfig kube-proxy.kubeconfig ubuntu@${external_ip}:~/
# done

# for ((i=0;i<${number_of_controllers};i+=1)); do
#   instance="controller-${i}"
#   external_ip=$(aws ec2 describe-instances --filters \
#     "Name=tag:Name,Values=${instance}" \
#     "Name=instance-state-name,Values=running" \
#     --output text --query 'Reservations[].Instances[].PublicIpAddress')

#   scp -i kubernetes.id_rsa \
#     admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig ubuntu@${external_ip}:~/
# done

# # Generating the Data Encryption Config and Key
# echo "Generating data encryption config and key..."
# ## The Encryption Key
# ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

# ## The Encryption Config File
# cat > encryption-config.yaml <<EOF
# kind: EncryptionConfig
# apiVersion: v1
# resources:
#   - resources:
#       - secrets
#     providers:
#       - aescbc:
#           keys:
#             - name: key1
#               secret: ${ENCRYPTION_KEY}
#       - identity: {}
# EOF

# for ((i=0;i<${number_of_controllers};i+=1)); do
#   instance="controller-${i}"
#   external_ip=$(aws ec2 describe-instances --filters \
#     "Name=tag:Name,Values=${instance}" \
#     "Name=instance-state-name,Values=running" \
#     --output text --query 'Reservations[].Instances[].PublicIpAddress')

#   scp -i kubernetes.id_rsa encryption-config.yaml ubuntu@${external_ip}:~/
# done

# # Bootstrapping the etcd Cluster
# cat <<EOF > etcd_conf.sh
# INTERNAL_IP=\$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
# wget -q --show-progress --https-only --timestamping "https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz"
# tar -xvf etcd-${ETCD_VERSION}-linux-amd64.tar.gz
# sudo mv etcd-${ETCD_VERSION}-linux-amd64/etcd* /usr/local/bin/
# sudo mkdir -p /etc/etcd /var/lib/etcd
# sudo chmod 700 /var/lib/etcd
# sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
# sudo chmod 600 /etc/etcd/*.pem
# sudo chown root:root /etc/etcd/*.pem
# ETCD_NAME=\$(curl -s http://169.254.169.254/latest/user-data/ \
#   | tr "|" "\n" | grep "^name" | cut -d"=" -f2)
# echo "\${ETCD_NAME}"
# cat << ENDSVCFILE | sudo tee /etc/systemd/system/etcd.service
# [Unit]
# Description=etcd
# Documentation=https://github.com/coreos

# [Service]
# Type=notify
# ExecStart=/usr/local/bin/etcd \\
#   --name \${ETCD_NAME} \\
#   --cert-file=/etc/etcd/kubernetes.pem \\
#   --key-file=/etc/etcd/kubernetes-key.pem \\
#   --peer-cert-file=/etc/etcd/kubernetes.pem \\
#   --peer-key-file=/etc/etcd/kubernetes-key.pem \\
#   --trusted-ca-file=/etc/etcd/ca.pem \\
#   --peer-trusted-ca-file=/etc/etcd/ca.pem \\
#   --peer-client-cert-auth \\
#   --client-cert-auth \\
#   --initial-advertise-peer-urls https://\${INTERNAL_IP}:2380 \\
#   --listen-peer-urls https://\${INTERNAL_IP}:2380 \\
#   --listen-client-urls https://\${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
#   --advertise-client-urls https://\${INTERNAL_IP}:2379 \\
#   --initial-cluster-token etcd-cluster-0 \\
#   --initial-cluster controller-0=https://10.0.1.10:2380,controller-1=https://10.0.1.11:2380,controller-2=https://10.0.1.12:2380 \\
#   --initial-cluster-state new \\
#   --data-dir=/var/lib/etcd
# Restart=on-failure
# RestartSec=5

# [Install]
# WantedBy=multi-user.target
# ENDSVCFILE

# sudo systemctl daemon-reload
# sudo systemctl enable etcd
# sudo systemctl start etcd
# EOF

# for ((i=0;i<${number_of_controllers};i+=1)); do
#   instance="controller-${i}"
#   external_ip=$(aws ec2 describe-instances --filters \
#     "Name=tag:Name,Values=${instance}" \
#     "Name=instance-state-name,Values=running" \
#     --output text --query 'Reservations[].Instances[].PublicIpAddress')
#   scp -i kubernetes.id_rsa etcd_conf.sh ubuntu@${external_ip}:~/
#   ssh -i kubernetes.id_rsa ubuntu@${external_ip} "chmod u+x etcd_conf.sh && ./etcd_conf.sh"
# done

# check_etcd_status() {
#   external_ip=$(aws ec2 describe-instances --filters \
#     "Name=tag:Name,Values=controller-2" \
#     "Name=instance-state-name,Values=running" \
#     --output text --query 'Reservations[].Instances[].PublicIpAddress')
#   ssh -i kubernetes.id_rsa ubuntu@${external_ip} "sudo ETCDCTL_API=3 etcdctl member list --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem"
# }

# check_etcd_status
# rm -f etcd_conf.sh

# # Bootstrapping the Kubernetes Control Plane
# echo "Bootstrapping the Kubernetes Control Plane..."

# cat << EOF > k8s_control_plane.sh
# INTERNAL_IP=\$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
# sudo mkdir -p /etc/kubernetes/config
# wget -q --show-progress --https-only --timestamping \
#   "https://dl.k8s.io/${k8s_version}/bin/linux/amd64/kube-apiserver" \
#   "https://dl.k8s.io/${k8s_version}/bin/linux/amd64/kube-controller-manager" \
#   "https://dl.k8s.io/${k8s_version}/bin/linux/amd64/kube-scheduler" \
#   "https://dl.k8s.io/${k8s_version}/bin/linux/amd64/kubectl"
# chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
# sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
# sudo mkdir -p /var/lib/kubernetes/

# sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem service-account-key.pem service-account.pem encryption-config.yaml /var/lib/kubernetes/
# sudo chown -R root:root /var/lib/kubernetes/
# cat <<EOFAPISERVER | sudo tee /etc/systemd/system/kube-apiserver.service
# [Unit]
# Description=Kubernetes API Server
# Documentation=https://github.com/kubernetes/kubernetes

# [Service]
# ExecStart=/usr/local/bin/kube-apiserver \\
#   --advertise-address=\${INTERNAL_IP} \\
#   --allow-privileged=true \\
#   --apiserver-count=3 \\
#   --audit-log-maxage=30 \\
#   --audit-log-maxbackup=3 \\
#   --audit-log-maxsize=100 \\
#   --audit-log-path=/var/log/audit.log \\
#   --authorization-mode=Node,RBAC \\
#   --bind-address=0.0.0.0 \\
#   --client-ca-file=/var/lib/kubernetes/ca.pem \\
#   --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
#   --etcd-cafile=/var/lib/kubernetes/ca.pem \\
#   --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
#   --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
#   --etcd-servers=https://10.0.1.10:2379,https://10.0.1.11:2379,https://10.0.1.12:2379 \\
#   --event-ttl=1h \\
#   --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
#   --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
#   --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
#   --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
#   --runtime-config='api/all=true' \\
#   --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
#   --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem \\
#   --service-account-issuer=https://${KUBERNETES_PUBLIC_ADDRESS}:443 \\
#   --service-cluster-ip-range=10.32.0.0/24 \\
#   --service-node-port-range=30000-32767 \\
#   --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
#   --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
#   --v=2
# Restart=on-failure
# RestartSec=5

# [Install]
# WantedBy=multi-user.target
# EOFAPISERVER

# sudo mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
# sudo chown root:root /var/lib/kubernetes/kube-controller-manager.kubeconfig
# cat <<EOFCONTROLLER | sudo tee /etc/systemd/system/kube-controller-manager.service
# [Unit]
# Description=Kubernetes Controller Manager
# Documentation=https://github.com/kubernetes/kubernetes

# [Service]
# ExecStart=/usr/local/bin/kube-controller-manager \\
#   --bind-address=0.0.0.0 \\
#   --cluster-cidr=10.200.0.0/16 \\
#   --cluster-name=kubernetes \\
#   --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
#   --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
#   --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
#   --leader-elect=true \\
#   --root-ca-file=/var/lib/kubernetes/ca.pem \\
#   --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
#   --service-cluster-ip-range=10.32.0.0/24 \\
#   --use-service-account-credentials=true \\
#   --v=2
# Restart=on-failure
# RestartSec=5

# [Install]
# WantedBy=multi-user.target
# EOFCONTROLLER

# cat <<EOFSCHEDULERYML | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
# apiVersion: kubescheduler.config.k8s.io/v1
# kind: KubeSchedulerConfiguration
# clientConnection:
#   kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
# leaderElection:
#   leaderElect: true
# EOFSCHEDULERYML

# sudo mv kube-scheduler.kubeconfig /var/lib/kubernetes/
# sudo chown root:root /var/lib/kubernetes/kube-scheduler.kubeconfig
# cat <<EOFSCHEDULER | sudo tee /etc/systemd/system/kube-scheduler.service
# [Unit]
# Description=Kubernetes Scheduler
# Documentation=https://github.com/kubernetes/kubernetes

# [Service]
# ExecStart=/usr/local/bin/kube-scheduler \\
#   --config=/etc/kubernetes/config/kube-scheduler.yaml \\
#   --v=2
# Restart=on-failure
# RestartSec=5

# [Install]
# WantedBy=multi-user.target
# EOFSCHEDULER

# sudo systemctl daemon-reload
# sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
# sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler

# sleep 20

# cat <<EOFHOSTS | sudo tee -a /etc/hosts
# 10.0.1.20 ip-10-0-1-20
# 10.0.1.21 ip-10-0-1-21
# 10.0.1.22 ip-10-0-1-22
# EOFHOSTS
# EOF

# for ((i=0;i<${number_of_controllers};i+=1)); do
#   instance="controller-${i}"
#   external_ip=$(aws ec2 describe-instances --filters \
#     "Name=tag:Name,Values=${instance}" \
#     "Name=instance-state-name,Values=running" \
#     --output text --query 'Reservations[].Instances[].PublicIpAddress')
#   scp -i kubernetes.id_rsa k8s_control_plane.sh ubuntu@${external_ip}:~/
#   ssh -i kubernetes.id_rsa ubuntu@$external_ip "chmod u+x k8s_control_plane.sh && ./k8s_control_plane.sh && rm -f k8s_control_plane.sh"
# done

# # RBAC for Kubelet Authorization
# echo "Configuring RBAC for kubelet authorization..."
# external_ip=$(aws ec2 describe-instances --filters \
#     "Name=tag:Name,Values=controller-2" \
#     "Name=instance-state-name,Values=running" \
#     --output text --query 'Reservations[].Instances[].PublicIpAddress')
# cat <<EOFRBACCR > rbac-kubelet-to-kube-apiserver.yaml
# apiVersion: rbac.authorization.k8s.io/v1
# kind: ClusterRole
# metadata:
#   annotations:
#     rbac.authorization.kubernetes.io/autoupdate: "true"
#   labels:
#     kubernetes.io/bootstrapping: rbac-defaults
#   name: system:kube-apiserver-to-kubelet
# rules:
#   - apiGroups:
#       - ""
#     resources:
#       - nodes/proxy
#       - nodes/stats
#       - nodes/log
#       - nodes/spec
#       - nodes/metrics
#     verbs:
#       - "*"
# EOFRBACCR

# scp -i kubernetes.id_rsa rbac-kubelet-to-kube-apiserver.yaml ubuntu@${external_ip}:~/
# ssh -i kubernetes.id_rsa ubuntu@$external_ip "kubectl apply --kubeconfig admin.kubeconfig -f rbac-kubelet-to-kube-apiserver.yaml"

# cat <<EOFRBACCR > rbac-kubelet-to-kubelet-kubernetes-user.yaml
# apiVersion: rbac.authorization.k8s.io/v1
# kind: ClusterRoleBinding
# metadata:
#   name: system:kube-apiserver
#   namespace: ""
# roleRef:
#   apiGroup: rbac.authorization.k8s.io
#   kind: ClusterRole
#   name: system:kube-apiserver-to-kubelet
# subjects:
#   - apiGroup: rbac.authorization.k8s.io
#     kind: User
#     name: kubernetes
# EOFRBACCR

# scp -i kubernetes.id_rsa rbac-kubelet-to-kubelet-kubernetes-user.yaml ubuntu@${external_ip}:~/
# ssh -i kubernetes.id_rsa ubuntu@$external_ip "kubectl apply --kubeconfig admin.kubeconfig -f rbac-kubelet-to-kubelet-kubernetes-user.yaml"

# # Verification of cluster public endpoint
# echo "Verifying cluster public endpoint..."
# KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers \
#   --load-balancer-arns ${LOAD_BALANCER_ARN} \
#   --output text --query 'LoadBalancers[].DNSName')
# curl --cacert ca.pem https://${KUBERNETES_PUBLIC_ADDRESS}/version

# # Bootstrapping the Kubernetes Worker Nodes
# echo "Bootstrapping the Kubernetes Worker Nodes..."
# cat <<EOF > k8s_worker.sh
# sudo apt-get update
# sudo apt-get -y install socat conntrack ipset
# sudo swapon --show
# sudo swapoff -a
# sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# wget -q --show-progress --https-only --timestamping \
#   https://github.com/kubernetes-sigs/cri-tools/releases/download/${k8s_version}/crictl-${k8s_version}-linux-amd64.tar.gz \
#   https://github.com/opencontainers/runc/releases/download/${runc_version}/runc.amd64 \
#   https://github.com/containernetworking/plugins/releases/download/${cni_plugins_version}/cni-plugins-linux-amd64-${cni_plugins_version}.tgz \
#   https://github.com/containerd/containerd/releases/download/v${containerd_version}/containerd-${containerd_version}-linux-amd64.tar.gz \
#   https://dl.k8s.io/${k8s_version}/bin/linux/amd64/kubectl \
#   https://dl.k8s.io/${k8s_version}/bin/linux/amd64/kube-proxy \
#   https://dl.k8s.io/${k8s_version}/bin/linux/amd64/kubelet

# sudo mkdir -p \
#   /etc/cni/net.d \
#   /opt/cni/bin \
#   /var/lib/kubelet \
#   /var/lib/kube-proxy \
#   /var/lib/kubernetes \
#   /var/run/kubernetes

# mkdir containerd
# tar -xvf crictl-${k8s_version}-linux-amd64.tar.gz
# tar -xvf containerd-${containerd_version}-linux-amd64.tar.gz -C containerd
# sudo tar -xvf cni-plugins-linux-amd64-${cni_plugins_version}.tgz -C /opt/cni/bin/
# sudo mv runc.amd64 runc
# chmod +x crictl kubectl kube-proxy kubelet runc 
# sudo mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/
# sudo mv containerd/bin/* /bin/

# POD_CIDR=\$(curl -s http://169.254.169.254/latest/user-data/ \
#   | tr "|" "\n" | grep "^pod-cidr" | cut -d"=" -f2)
# echo "\${POD_CIDR}"

# cat <<EOFCNI | sudo tee /etc/cni/net.d/10-bridge.conf
# {
#     "cniVersion": "0.4.0",
#     "name": "bridge",
#     "type": "bridge",
#     "bridge": "cnio0",
#     "isGateway": true,
#     "ipMasq": true,
#     "ipam": {
#         "type": "host-local",
#         "ranges": [
#           [{"subnet": "\${POD_CIDR}"}]
#         ],
#         "routes": [{"dst": "0.0.0.0/0"}]
#     }
# }
# EOFCNI

# cat <<EOFLOOP | sudo tee /etc/cni/net.d/99-loopback.conf
# {
#     "cniVersion": "0.4.0",
#     "name": "lo",
#     "type": "loopback"
# }
# EOFLOOP

# sudo mkdir -p /etc/containerd/
# cat << EOFCRI | sudo tee /etc/containerd/config.toml
# [plugins]
#   [plugins.cri.containerd]
#     snapshotter = "overlayfs"
#     [plugins.cri.containerd.default_runtime]
#       runtime_type = "io.containerd.runtime.v1.linux"
#       runtime_engine = "/usr/local/bin/runc"
#       runtime_root = ""
# EOFCRI

# cat <<EOFCRISVC | sudo tee /etc/systemd/system/containerd.service
# [Unit]
# Description=containerd container runtime
# Documentation=https://containerd.io
# After=network.target

# [Service]
# ExecStartPre=/sbin/modprobe overlay
# ExecStart=/bin/containerd
# Restart=always
# RestartSec=5
# Delegate=yes
# KillMode=process
# OOMScoreAdjust=-999
# LimitNOFILE=1048576
# LimitNPROC=infinity
# LimitCORE=infinity

# [Install]
# WantedBy=multi-user.target
# EOFCRISVC

# WORKER_NAME=\$(curl -s http://169.254.169.254/latest/user-data/ \
# | tr "|" "\n" | grep "^name" | cut -d"=" -f2)
# echo "\${WORKER_NAME}"

# sudo mv \${WORKER_NAME}-key.pem \${WORKER_NAME}.pem /var/lib/kubelet/
# sudo mv \${WORKER_NAME}.kubeconfig /var/lib/kubelet/kubeconfig
# sudo chown root:root /var/lib/kubelet/*
# sudo mv ca.pem /var/lib/kubernetes/
# sudo chown root:root /var/lib/kubernetes/*

# cat <<EOFKUBELET | sudo tee /var/lib/kubelet/kubelet-config.yaml
# kind: KubeletConfiguration
# apiVersion: kubelet.config.k8s.io/v1beta1
# authentication:
#   anonymous:
#     enabled: false
#   webhook:
#     enabled: true
#   x509:
#     clientCAFile: "/var/lib/kubernetes/ca.pem"
# authorization:
#   mode: Webhook
# clusterDomain: "cluster.local"
# clusterDNS:
#   - "10.32.0.10"
# podCIDR: "\${POD_CIDR}"
# resolvConf: "/run/systemd/resolve/resolv.conf"
# runtimeRequestTimeout: "15m"
# tlsCertFile: "/var/lib/kubelet/\${WORKER_NAME}.pem"
# tlsPrivateKeyFile: "/var/lib/kubelet/\${WORKER_NAME}-key.pem"
# EOFKUBELET

# cat <<EOFKUBELETSVC | sudo tee /etc/systemd/system/kubelet.service
# [Unit]
# Description=Kubernetes Kubelet
# Documentation=https://github.com/kubernetes/kubernetes
# After=containerd.service
# Requires=containerd.service

# [Service]
# ExecStart=/usr/local/bin/kubelet \\
#   --config=/var/lib/kubelet/kubelet-config.yaml \\
#   --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
#   --kubeconfig=/var/lib/kubelet/kubeconfig \\
#   --register-node=true \\
#   --v=2
# Restart=on-failure
# RestartSec=5

# [Install]
# WantedBy=multi-user.target
# EOFKUBELETSVC

# sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
# sudo chown root:root /var/lib/kube-proxy/kubeconfig
# cat <<EOFKUBEPROXY | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
# kind: KubeProxyConfiguration
# apiVersion: kubeproxy.config.k8s.io/v1alpha1
# clientConnection:
#   kubeconfig: "/var/lib/kube-proxy/kubeconfig"
# mode: "iptables"
# clusterCIDR: "10.200.0.0/16"
# EOFKUBEPROXY

# cat <<EOFPROXYSVC | sudo tee /etc/systemd/system/kube-proxy.service
# [Unit]
# Description=Kubernetes Kube Proxy
# Documentation=https://github.com/kubernetes/kubernetes

# [Service]
# ExecStart=/usr/local/bin/kube-proxy \\
#   --config=/var/lib/kube-proxy/kube-proxy-config.yaml
# Restart=on-failure
# RestartSec=5

# [Install]
# WantedBy=multi-user.target
# EOFPROXYSVC

# sudo systemctl daemon-reload
# sudo systemctl enable containerd kubelet kube-proxy
# sudo systemctl start containerd kubelet kube-proxy
# EOF

# for ((i=0;i<${number_of_workers};i+=1)); do
#   instance="worker-${i}"
#   external_ip=$(aws ec2 describe-instances --filters \
#     "Name=tag:Name,Values=${instance}" \
#     "Name=instance-state-name,Values=running" \
#     --output text --query 'Reservations[].Instances[].PublicIpAddress')
#   scp -i kubernetes.id_rsa k8s_worker.sh ubuntu@${external_ip}:~/
#   ssh -i kubernetes.id_rsa ubuntu@${external_ip} "chmod u+x k8s_worker.sh && ./k8s_worker.sh && rm -f k8s_worker.sh"
# done

# # Verify the worker nodes
# external_ip=$(aws ec2 describe-instances --filters \
#     "Name=tag:Name,Values=controller-0" \
#     "Name=instance-state-name,Values=running" \
#     --output text --query 'Reservations[].Instances[].PublicIpAddress')

# ssh -i kubernetes.id_rsa ubuntu@${external_ip} kubectl get nodes --kubeconfig admin.kubeconfig

# # Configuring kubectl for Remote Access
# echo "Configuring kubectl for remote access..."
# ## The Admin Kubernetes Configuration File
# KUBERNETES_PUBLIC_ADDRESS=$(aws elbv2 describe-load-balancers \
# --load-balancer-arns ${LOAD_BALANCER_ARN} \
# --output text --query 'LoadBalancers[].DNSName')

# kubectl config set-cluster ${CLUSTER_NAME} \
#   --certificate-authority=ca.pem \
#   --embed-certs=true \
#   --server=https://${KUBERNETES_PUBLIC_ADDRESS}:443

# kubectl config set-credentials admin \
#   --client-certificate=admin.pem \
#   --client-key=admin-key.pem

# kubectl config set-context ${CLUSTER_NAME} \
#   --cluster=${CLUSTER_NAME} \
#   --user=admin

# kubectl config use-context ${CLUSTER_NAME}

# # Verification
# echo "Verifying the cluster..."
# kubectl get componentstatuses
# kubectl get nodes

# # The Routing Table and routes
# echo "Configuring the routing table and routes..."

# for ((i=0;i<${number_of_workers};i+=1)); do
#   instance="worker-${i}"
#   instance_id_ip="$(aws ec2 describe-instances \
#     --filters "Name=tag:Name,Values=${instance}" \
#     --output text --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress]'| grep -v None)"
#   instance_id="$(echo "${instance_id_ip}" | cut -f1)"
#   instance_ip="$(echo "${instance_id_ip}" | cut -f2)"
#   pod_cidr="$(aws ec2 describe-instance-attribute \
#     --instance-id "${instance_id}" \
#     --attribute userData \
#     --output text --query 'UserData.Value' \
#     | base64 --decode | tr "|" "\n" | grep "^pod-cidr" | cut -d'=' -f2)"
#   route_table_id="$(aws ec2 describe-route-tables \
#     --filters "Name=tag:Name,Values=${CLUSTER_NAME}" \
#     --output text --query 'RouteTables[].Associations[].RouteTableId')"
#   echo "${instance_ip} ${pod_cidr}"

#   aws ec2 create-route \
#     --route-table-id "${route_table_id}" \
#     --destination-cidr-block "${pod_cidr}" \
#     --instance-id "${instance_id}"
# done

# # Validate Routes
# echo "Validating routes..."
# aws ec2 describe-route-tables \
#   --route-table-ids "${route_table_id}" \
#   --query 'RouteTables[].Routes'

# # private user configuration
# kubectl config use-context ${CLUSTER_NAME}


# Cleanup
# cwd=$(pwd)
# aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances --filters "Name=key-name,Values=kubernetes" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].{InstanceId:InstanceId}" --output text | xargs)
# sleep 120 | pv -t
# aws ec2 delete-key-pair --key-name kubernetes
# rm -f $cwd/*
# lbarn=$(aws elbv2 describe-load-balancers | jq -r '.LoadBalancers[] | select(.LoadBalancerName | contains("kubernetes")) .LoadBalancerArn')
# aws elbv2 delete-load-balancer --load-balancer-arn $lbarn
# tgarn=$(aws elbv2 describe-target-groups | jq -r '.TargetGroups[] | select(.TargetGroupName | contains("kubernetes")) .TargetGroupArn')
# aws elbv2 delete-target-group --target-group-arn $tgarn
# VPC_ID=$(aws ec2 describe-vpcs | jq -r '.Vpcs[] | select(.Tags[]?.Value | contains("kubernetes")) .VpcId')
# IGWS=$(aws ec2 describe-internet-gateways --filter "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[*].InternetGatewayId" --output text)
# for igw in $IGWS; do
#   aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $VPC_ID
#   aws ec2 delete-internet-gateway --internet-gateway-id $igw
# done
# ROUTE_TABLES=$(aws ec2 describe-route-tables --filter "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[?Main!=true]].RouteTableId" --output text)
# for rt in $ROUTE_TABLES; do
#   aws ec2 delete-route-table --route-table-id $rt
# done
# SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text)
# for subnet in $SUBNETS; do
#   aws ec2 delete-subnet --subnet-id $subnet
# done
# SECURITY_GROUPS=$(aws ec2 describe-security-groups --filter "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
# for sg in $SECURITY_GROUPS; do
#   aws ec2 delete-security-group --group-id $sg
# done
# aws ec2 delete-vpc --vpc-id $VPC_ID
