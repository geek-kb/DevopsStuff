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
        if [ "$os_dist" == "ubuntu" ]; then
            os_distribution="ubuntu"
        elif [ "$os_dist" == "centos" ]; then
            os_distribution="centos"
        else
            echo "Unsupported Linux distribution"
            return 1
        fi
    elif [ "$os_type" == "Darwin" ]; then
        os_distribution="darwin"
    else
        echo "Unsupported OS"
        return 1
    fi
    echo $os_distribution
}

function install_openssl() {
    os_distribution=$(get_os_type)
    if [ "$os_distribution" == "ubuntu" ]; then
        sudo apt-get update
        sudo apt-get install -y openssl
    elif [ "$os_distribution" == "centos" ]; then
        sudo yum install -y openssl
    elif [ "$os_distribution" == "darwin" ]; then
        brew install openssl
    else
        echo "Unsupported OS"
        return 1
    fi
}

function install_easyrsa() {
    os_distribution=$(get_os_type)
    if [ "$os_distribution" == "ubuntu" ]; then
        sudo apt-get update
        sudo apt-get install -y easy-rsa
    elif [ "$os_distribution" == "centos" ]; then
        sudo yum install -y easy-rsa
    elif [ "$os_distribution" == "darwin" ]; then
        brew install easy-rsa
    else
        echo "Unsupported OS"
        return 1
    fi
}

function install_cfssl() {
    os_distribution=$(get_os_type)
    if [ "$os_distribution" == "ubuntu" ]; then
        sudo apt-get update
        sudo apt-get install -y cfssl
    elif [ "$os_distribution" == "centos" ]; then
        sudo yum install -y cfssl
    elif [ "$os_distribution" == "darwin" ]; then
        brew install cfssl
    else
        echo "Unsupported OS"
        return 1
    fi
}

echo "Select the certificate generation tool to use for generating the certificates for the K8s cluster components"
echo " "
select GEN_TOOL in 'openssl' 'easyrsa' 'cfssl'; do
    which $GEN_TOOL
    if [ $? -ne 0 ]; then
        echo "The selected tool is not installed"
        echo "Installing $GEN_TOOL"
        if [ "$GEN_TOOL" = "openssl" ]; then
            install_openssl
        elif [ "$GEN_TOOL" = "easyrsa" ]; then
            install_easyrsa
        elif [ "$GEN_TOOL" = "cfssl" ]; then
            install_cfssl
        fi
    else
        echo "The selected tool is installed"
    fi
    if [ "$GEN_TOOL" = "openssl" ]; then
        echo "You have selected $GEN_TOOL"
        echo "Generating certificates using $GEN_TOOL"    
        for cert_type in $certificates_list; do
            mkdir -p $cert_path/$cert_type        
            for cert in $cert_type; do
                echo "Creating directory for $cert certificate"
                mkdir -p $cert && cd $cert
                echo "Generating $cert certificate"
                openssl genrsa -out $cert.key 2048
                openssl req -new -key $cert.key -out $cert.csr -subj "/CN=$cert"
                if [ "$cert" = "ca" ]; then
                    openssl x509 -req -in $cert.csr -signkey $cert.key -out $cert.crt
                else
                    openssl x509 -req -in $cert.csr -CA $ca_cert_path/ca.crt -CAkey $ca_cert_path/ca.key -out $cert.crt
                fi
                cd ../
            done
        done
    break
    elif [ "$GEN_TOOL" = "easyrsa" ]; then
        echo "You have selected $GEN_TOOL"
        echo "Generating certificates using $GEN_TOOL"
        for cert_type in $certificates_list; do
            mkdir -p $cert_path/$cert_type
            for cert in $cert_type; do
                echo "Creating directory for $cert certificate"
                mkdir -p $cert && cd $cert
                echo "Generating $cert certificate"
                easyrsa init-pki
                easyrsa build-ca nopass
                if [ "$cert" = "ca" ]; then
                    easyrsa build-server-full $cert nopass
                else
                    easyrsa build-client-full $cert nopass
                fi
                cd ../
            done         
        done
    break
    elif [ "$GEN_TOOL" = "cfssl" ]; then
        echo "You have selected $GEN_TOOL"
        echo "Generating certificates using $GEN_TOOL"
        for cert_type in $certificates_list; do
            mkdir -p $cert_path/$cert_type
            for cert in $cert_type; do
                echo "Creating directory for $cert certificate"
                mkdir -p $cert && cd $cert
                echo "Generating $cert certificate"
                cfssl gencert -initca ca-csr.json | cfssljson -bare ca
                if [ "$cert" = "ca" ]; then
                    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=server server-csr.json | cfssljson -bare server
                    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=client client-csr.json | cfssljson -bare client
                fi
                cd ../
            done
        done
    break
    fi
done
echo "Certificates generated successfully"
echo " "
