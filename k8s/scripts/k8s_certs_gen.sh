#!/bin/bash
# K8s Certifications generation script
# Script by Itai Ganot 2024

server_certificates_list="kube-apiserver etcd-server kubelet"
client_certificates_list="kube-controller-manager kube-scheduler kube-proxy kubelet etcd-client admin apiserver-kubelet-client"
ca_certificates_list="ca"
certificates_list="$ca_certificates_list $server_certificates_list $client_certificates_list"
certificate_gen_tools="openssl easyrsa cfssl"

read -r -p "Enter the path to store the certificates: " cert_path
mkdir -p $cert_path && cd $cert_path

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
        else    
            openssl req -new -key $cert.key -out $cert.csr -subj "/CN=kubernetes-$cert"
            openssl x509 -req -in $cert.csr -CA $ca_cert_path/ca.crt -CAkey $ca_cert_path/ca.key -out $cert.crt
        fi
        cd ../
    done
done


echo "Certificates generated successfully"
echo " "
