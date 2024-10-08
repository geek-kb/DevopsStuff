#!/bin/bash
# Aliases and functions to speed working with Kubernetes command line tool
# Itai Ganot, 2024
kubectl_bin=$(which kubectl)
alias k=${kubectl_bin}
function kgpy() {
    kubectl get pod "$1" -o yaml > "${1}_pod.yaml"
}
function kgsy() {
    kubectl get svc "$1" -o yaml > "${1}_svc.yaml"
}
function kgdy() {
    kubectl get deploy "$1" -o yaml > "${1}_deploy.yaml"
}
do=' --dry-run=client -o yaml '
function kry() {
    kubectl run "$1" --image="$2" $do > "${1}.yaml"
}
function kubesec() {
    local FILE="${1:-}";
    [[ ! -e "${FILE}" ]] && {
        echo "kubesec: ${FILE}: No such file" >&2;
        return 1
    };
    curl --silent \
      --compressed \
      --connect-timeout 5 \
      -sSX POST \
      --data-binary @"${FILE}" \
      https://v2.kubesec.io/scan \
      | jq
}
alias kg='kubectl get '
alias kd='kubectl describe '
alias ksysgp='kubectl --namespace=kube-system get pod'
alias kgpw='kubectl get pod -o wide '
