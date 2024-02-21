#!/bin/bash
# K8s Certifications generation script
# Script by Itai Ganot 2024

server_certificates_list="kube-apiserver etcd-server kubelet-server"
client_certificates_list="kube-controller-manager kube-scheduler kube-proxy kubelet etcd-client admin apiserver-kubelet-client"
ca_certificates_list="ca"
certificates_list="$ca_certificates_list $server_certificates_list $client_certificates_list"
certificate_gen_tools="openssl easyrsa cfssl"

read -r -p "Enter the path to store the certificates: " cert_path
mkdir -p $cert_path && cd $cert_path

echo "The following details are required for the generation of the certificates:"
read -r -p "Enter the IP address of the kube-apiserver: " kube_apiserver_ip
read -r -p "Enter the IP address of the pod running the kube-apiserver: " kube_apiserver_pod_ip
read -r -p "Enter the number of days for the certificate to be valid: " cert_days
read -r -p "Enter the names of the nodes in the cluster: " nodes

function get_os_type() {
    os_type=$(uname -s)
    if [ "$os_type" = "Linux" ]; then
        os_dist=$(uname -n)
        if [ "$os_dist" = "ubuntu" ]; then
            os_distribution="ubuntu"
        elif [ "$os_dist" = "centos" ]; then
            os_distribution="centos"
        else
            echo "Unsupported Linux distribution"
            return 1
        fi
    elif [ "$os_type" = "Darwin" ]; then
        os_distribution="darwin"
    else
        echo "Unsupported OS"
        return 1
    fi
    echo $os_distribution
}

function install_openssl() {
    os_distribution=$(get_os_type)
    if [ "$os_distribution" = "ubuntu" ]; then
        sudo apt-get update
        sudo apt-get install -y openssl
    elif [ "$os_distribution" = "centos" ]; then
        sudo yum install -y openssl
    elif [ "$os_distribution" = "darwin" ]; then
        brew install openssl
    else
        echo "Unsupported OS"
        return 1
    fi
}

echo "Checking if openssl is installed"
which openssl
if [ $? -ne 0 ]; then
    echo "Package openssl is not installed, installing..."
    install_openssl
else
    echo "Package openssl is installed"
fi

echo "Generating certificates using openssl"    
for cert_type in $certificates_list; do
    mkdir -p $cert_path/$cert_type        
    for cert in $cert_type; do
        echo "Creating directory for $cert certificate"
        mkdir -p $cert && cd $cert
        echo "Generating $cert certificate"
        openssl genrsa -out $cert.key 2048
        if [ "$cert" = "ca" ]; then
            openssl req -new -key $cert.key -out $cert.csr -subj "/CN=kubernetes-ca"
            openssl x509 -req -in $cert.csr -signkey $cert.key -out $cert.crt
            ca_cert_path=$cert_path/$cert
        elif [ $cert = "kube-scheduler" ]; then
            openssl req -new -key $cert.key -out $cert.csr -subj "/CN=system:kube-scheduler"
            openssl x509 -req -in $cert.csr -CA $ca_cert_path/ca.crt -CAkey $ca_cert_path/ca.key -out $cert.crt
        elif [ $cert = "kubelet-server" ]; then
            if [ -z "$nodes" ]; then
                echo "The names of the nodes in the cluster are required"
                exit 1
            fi
            for node in $nodes; do
                openssl req -new -key $cert.key -out $cert-$node.csr -subj "/CN=system:node:$node"
                openssl x509 -req -in $cert-$node.csr -CA $ca_cert_path/ca.crt -CAkey $ca_cert_path/ca.key -out $cert-$node.crt
            done
        elif [ $cert = "kube-controller-manager" ]; then
            openssl req -new -key $cert.key -out $cert.csr -subj "/CN=system:kube-controller-manager"
            openssl x509 -req -in $cert.csr -CA $ca_cert_path/ca.crt -CAkey $ca_cert_path/ca.key -out $cert.crt
        elif [ $cert = "kubelet" ]; then
            openssl req -new -key $cert.key -out $cert.csr -subj "/CN=system:node:kubelet"
            openssl x509 -req -in $cert.csr -CA $ca_cert_path/ca.crt -CAkey $ca_cert_path/ca.key -out $cert.crt
        elif [ $cert = "kube-proxy" ]; then
            openssl req -new -key $cert.key -out $cert.csr -subj "/CN=system:node:kube-proxy"
            openssl x509 -req -in $cert.csr -CA $ca_cert_path/ca.crt -CAkey $ca_cert_path/ca.key -out $cert.crt
        elif [ $cert = "etcd-server" ]; then
            openssl req -new -key $cert.key -out $cert.csr -subj "/CN=etcd-server"
            openssl x509 -req -in $cert.csr -CA $ca_cert_path/ca.crt -CAkey $ca_cert_path/ca.key -out $cert.crt
        elif [ $cert = "etcd-client" ]; then
            openssl req -new -key $cert.key -out $cert.csr -subj "/CN=etcd-client"
            openssl x509 -req -in $cert.csr -CA $ca_cert_path/ca.crt -CAkey $ca_cert_path/ca.key -out $cert.crt
        elif [ "$cert" = "admin" ]; then
            openssl req -new -key $cert.key -out $cert.csr -subj "/CN=kubernetes-admin/O=system:masters"
            openssl x509 -req -in $cert.csr -CA $ca_cert_path/ca.crt -CAkey $ca_cert_path/ca.key -out $cert.crt
        elif [ "$cert" = "kube-apiserver" ]; then
            if [ -z "$kube_apiserver_ip" ] || [ -z "$kube_apiserver_pod_ip" ] || [ -z "$cert_days" ]; then
                echo "The kube-apiserver IP addresses and the number of days for the certificate to be valid are required"
                exit 1
            fi
            openssl req -new -key $cert.key -out $cert.csr -subj "/CN=kube-apiserver"
            cat <<EOF > openssl.cnf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
IP.1 = $kube_apiserver_ip
IP.2 = $kube_apiserver_pod_ip
EOF
            openssl x509 -req -in $cert.csr -CA $ca_cert_path/ca.crt -CAkey $ca_cert_path/ca.key -extfile openssl.cnf -extensions v3_req -out $cert.crt -days $cert_days
        else    
            openssl req -new -key $cert.key -out $cert.csr -subj "/CN=kubernetes-$cert"
            openssl x509 -req -in $cert.csr -CA $ca_cert_path/ca.crt -CAkey $ca_cert_path/ca.key -out $cert.crt
        fi
        cd ../
    done
done

echo "Certificates generated successfully"
echo " "
