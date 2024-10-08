#!/bin/bash
# This script generates required certificates for a new k8s admin user and configures kubeconfig to use that user.

USER=itaig
openssl genrsa -out ${USER}.key 2048
openssl req -new -key ${USER}.key -out ${USER}.csr -subj "/CN=${USER}"
request=$(cat ${USER}.csr | base64 | tr -d "\n")
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${USER}
spec:
  request: ${request}
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 88886400
  usages:
  - client auth
  - digital signature
  - key encipherment
EOF
kubectl certificate approve ${USER}
kubectl get csr ${USER} -o jsonpath='{.status.certificate}'| base64 -d > ${USER}.crt
kubectl create clusterrolebinding ${USER}-binding --clusterrole=cluster-admin --user=${USER}
kubectl config set-credentials ${USER} --client-key=${USER}.key --client-certificate=${USER}.crt --embed-certs=true
kubectl config set-context ${USER} --cluster=kubernetes --user=${USER}
kubectl config use-context ${USER}
