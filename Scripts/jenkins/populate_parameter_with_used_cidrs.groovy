#!/usr/local/bin/groovy
// Returns an array of current used CIDR blocks to avoid same CIDR block in an environments. 
// Can be used to populate a parameter in Jenkins + Extended Parameter plugin.
//  Script by Itai Ganot 2017
def regions = ['us-west-2', 'us-east-1', 'eu-west-1']
        def output = []
        regions.each { region ->
            def p = ['/usr/local/bin/aws', 'ec2', 'describe-vpcs', '--region', region].execute() | 'grep -w CidrBlock'.execute() | ['awk', '{print $2}'].execute() | ['tr', '-d', '"\\"\\|,\\|\\{\\|\\\\["'].execute() | 'uniq'.execute()
            p.waitFor()
            p.text.eachLine { line ->
								if (!(line =~ /^172\./)) output << line
            }
        }
				output = output.sort { a, b ->
    		def aparts = a.split('[./]').collect { it as short }
    		def bparts = b.split('[./]').collect { it as short }
    		(0..4).collect { aparts[it] <=> bparts[it] }.find() ?: 0
				}
        output.each {
            println it
        }
