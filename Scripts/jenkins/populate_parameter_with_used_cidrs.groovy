#!/usr/local/bin/groovy
# Returns an array of current used CIDR blocks to avoid same cidr in two environments. 
# Can be used to populate a parameter in Jenkins + Extended Parameter plugin.
# Script by Itai Ganot 2017
def p = ['/usr/local/bin/aws', 'ec2', 'describe-vpcs'].execute() | 'grep -w CidrBlock'.execute() | ['awk', '{print $2}'].execute() | ['tr', '-d', '"\\"\\|,\\|\\{\\|\\\\["'].execute() | 'uniq'.execute()
p.waitFor()
def output = []
p.text.eachLine { line ->
        output << line
}

output.each {
        println it
}
