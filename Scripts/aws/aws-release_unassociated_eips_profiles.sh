#!/bin/bash

# This script answers the security vulnerability of releasing an AWS elastic IP without making sure it is deleted from all security groups.
# Run the script and it will go through the list of AWS profiles, it will then check if there are any unassociated elastic ips and if such 
# an eip exists in any security group inbound rule.
# If the eip isn't found on any SG - it's allocationg will be released and if it's found in a SG, the rule containing the eip will be
# deleted and the allocation will be released.
# The script sends all the important output to a log file called the same as the script but ends with ".log".
# Script by Itai Ganot 2021

log_file="$(echo ${0::-3}).log"
export TERM=xterm-256color

# Functions
function usage(){
    # This function explains how to use the script
    echo "Please supply a regions list and aws profiles list"
    echo "${basename}${0} -r [regions list separated by comma] -p [profiles list separated by comma]"
}

function load_colors() {
    if [[ -z "${NOCOLOR}" ]]
    then
        export RED=$(tput setaf 1)
        export GREEN=$(tput setaf 2)
        export YELLOW=$(tput setaf 3)
        export BOLD=$(tput bold)
        export UNDERLINE=$(tput smul)
        export NOCOLOR=$(tput sgr0)
    fi
}

function timestamp(){
    # This function prints the current timestamp
    DATE=$(date +%Y-%m-%d)
    TIME=$(date +%H:%M:%S)
    ZONE=$(date +"%Z %z")
    echo "${DATE} ${TIME} ${ZONE}"
}

function logger(){
    # This functions prints all given commands colored and logs each command to the log file uncolored
    load_colors

    case "$1" in
        r)
        echo -e -n "$(timestamp) ${RED}$2 ${NOCOLOR}\n" | tee >(sed 's/\x1B[\[\(][0-9;]*[BJKmsu]//g' >> ${log_file})
        ;;
        g)
        echo -e -n "$(timestamp) ${GREEN}$2 ${NOCOLOR}\n" | tee >(sed 's/\x1B[\[\(][0-9;]*[BJKmsu]//g' >> ${log_file})
        ;;
        y)
        echo -e -n "$(timestamp) ${YELLOW}$2 ${NOCOLOR}\n" | tee >(sed 's/\x1B[\[\(][0-9;]*[BJKmsu]//g' >> ${log_file})
        ;;
        b)
        echo -e -n "$(timestamp) ${BOLD}$2 ${NOCOLOR}\n" | tee >(sed 's/\x1B[\[\(][0-9;]*[BJKmsu]//g' >> ${log_file})
        ;;
        u)
        echo -e -n "$(timestamp) ${UNDERLINE}$2 ${NOCOLOR}\n" | tee >(sed 's/\x1B[\[\(][0-9;]*[BJKmsu]//g' >> ${log_file})
        ;;
        n)
        echo -e -n "$(timestamp) $2\n" | tee -a "$log_file"
        ;;
        *)
        echo "Unknown color!"
        ;;
    esac
}

function install_deps(){
    # This function installs required dependancies
    deps="jq"
    flavor=$(cat /etc/*-release | grep ID_LIKE | awk -F= '{print $2}')
    case $flavor in
        debian)
        run_cmd="sudo apt install -y $*"
        ;;
        redhat)
        run_cmd="sudo yum install -y $*"
        ;;
    esac
    for dep in $(echo $deps | tr " " "\n"); do
        which "$dep" &>/dev/null
        if [[ "$?" -ne 0 ]]; then
            echo "The following dependancies are going to be installed: ${dep}"
            eval "$run_cmd ${dep}"
        fi
    done
}

function display_elastic_addresses(){
    aws ec2 describe-addresses --region "${region}" --profile "${prof}" | jq -r '.Addresses[]'
}

function display_null_association_allocationid(){
    aws ec2 describe-addresses --region "${region}" --profile "${prof}" | jq -r '.Addresses[] | select(.AssociationId == null) | .AllocationId'
}

function check_rule_number_exists(){
    rule_number_exists=$(jq -r --arg number "${number}" '.SecurityGroups[].IpPermissions[$number|tonumber]' "/tmp/${groupid}.txt")
    echo $rule_number_exists
}

function display_not_null_allocation_publicips(){
    aws ec2 describe-addresses --region "${region}" --profile "${prof}" | jq -r '.Addresses[] | select(.AssociationId != null) | .PublicIp'
}

function display_publicip_of_null_association(){
    aws ec2 describe-addresses --region "${region}" --profile "${prof}" | jq -r --arg eipalloc "${allocation}" '.Addresses[] | select(.AllocationId == $eipalloc) | .PublicIp'
}

function display_sg_ids_that_contains_rules_with_ip(){
    aws ec2 describe-security-groups --region "${region}" --profile "${prof}" | jq --arg ip "${ip}" -r '.SecurityGroups[] |select(.IpPermissions[].IpRanges[].CidrIp | contains($ip)) | .GroupId'
}

function describe_sg_to_file(){
    aws ec2 describe-security-groups --group-id "${groupid}" --region "${region}" --profile "${prof}" > "/tmp/${groupid}.txt"
}

function revoke_sg_rules(){
    FromPort=$(jq -r '.FromPort' "/tmp/${groupid}_${number}.txt")
    ToPort=$(jq -r '.ToPort' "/tmp/${groupid}_${number}.txt")
    Protocol=$(jq -r '.IpProtocol' "/tmp/${groupid}_${number}.txt")
    Cidr=$(jq -r '.IpRanges[].CidrIp' "/tmp/${groupid}_${number}.txt")
    Ip=$(echo ${Cidr} | awk -F/ '{print $1}')
    if [[ ${Ip} == ${ip} ]]; then
        logger n "aws ec2 revoke-security-group-ingress --region ${region} --group-id ${groupid} --ip-permissions IpProtocol=$Protocol,FromPort=$FromPort,ToPort=$ToPort,IpRanges=[{CidrIp=$Cidr}]"
        if [[ $? -eq 0 ]]; then
            logger g "The rule containing ip $ip has been deleted from security group $groupid successfully"
        else
            logger r "Unable to delete the rule containing ip $ip from security group $groupid"
        fi
    fi
    rm -f "/tmp/${groupid}_${number}.txt"
}

function break_sg_rules_to_files_and_revoke(){
    for number in $(seq 0 60); do
        rule_number=$(check_rule_number_exists)
        if [[ "${rule_number}" != null ]]; then
            jq -r --arg number "${number}" '.SecurityGroups[].IpPermissions[$number|tonumber]' "/tmp/${groupid}.txt" > "/tmp/${groupid}_${number}.txt"
            revoke_sg_rules
        else
            break
        fi
    done
}

function release_ec2-classic_eip(){
    aws ec2 release-address --public-ip "${ip}" --region "${region}" 2&>/dev/null
}

function release_vpc_eip(){
    aws ec2 release-address --allocation-id "${allocation}" --region "${region}"
}

function release_eip_addr(){
    logger g "Releasing ip $ip with AllocationId ${allocation}"
    echo release_ec2-classic_eip
    if [[ $? -eq 0 ]]; then
        logger g "Allocation released successfully!"
    else
        echo release_vpc_eip
        if [[ $? -eq 0 ]]; then
            logger g "Allocation released successfully!"
        else
            logger r "Failed to release allocation!"
        fi
    fi
}

# Arguments amount validation
if [[ $# -ne 4 ]]; then
    usage
    exit 1
fi

# Arguments handling
while getopts "r:p:" opt; do
    case "${opt}" in
        r)
        regions_list="${OPTARG}"
        regions=$(echo "${regions_list}" | tr "," "\n")
        ;;
        p)
        profile="${OPTARG}"
        ;;
        *)
        usage
        exit 1
        ;;
    esac
done

# Code
install_deps
for prof in $(echo ${profile} | tr " " "\n"); do
    for region in "${regions}"; do
        logger b "------------ Now working on profile ${prof} in region ${region}"
        addresses=$(display_elastic_addresses)
        if [[ -z "${addresses}" ]]; then
            logger g "No elastic ips found in profile ${prof} in region ${region}"
        else
            not_null_association_public_ips=$(display_not_null_allocation_publicips)
            logger g "The following IPs are allocated and associated:"
            logger n "$(echo ${not_null_association_public_ips} | xargs)"
            logger n "----------------------------------------------------------"
            null_association_allocationid=$(display_null_association_allocationid)
            if [[ -n "${null_association_allocationid}" ]]; then
                for allocation in "${null_association_allocationid}"; do
                    if [[ -n "${allocation}" ]]; then
                        ip=$(display_publicip_of_null_association)
                        logger y "Found unassociated elastic ips:"
                        logger n "${ip}"
                        groupids=$(display_sg_ids_that_contains_rules_with_ip)
                        if [[ -n "${groupids}" ]]; then
                            logger y "IP ${ip} found in groups:"
                            logger n "$(echo ${groupids} | xargs)"
                            for groupid in "${groupids}"; do
                                describe_sg_to_file
                                break_sg_rules_to_files_and_revoke
                                rm -f "/tmp/${groupid}.txt"
                                if [[ $? -eq 0 ]]; then
                                    logger g "The rule containing ip ${ip} has been deleted from security group ${groupid} successfully"
                                fi
                            done
                            release_eip_addr
                        else
                            logger g "IP ${ip} cannot be found in any security groups"
                            release_eip_addr
                        fi
                    fi
                done
            else
                logger g "No unassociated elastic ips found"
            fi
        fi
    done
done
logger n "End of run"
logger n "----------------------------------------------------------"
