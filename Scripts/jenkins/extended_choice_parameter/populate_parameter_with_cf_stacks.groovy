#!/usr/local/bin/groovy
// Returns an array of available Cloud Formation stacks in a given region. 
// Can be used to populate a parameter in Jenkins + Extended Parameter plugin.
// Script by Itai Ganot 2017
def region = "us-west-2"
        def output = []
        def p = ['/usr/local/bin/aws', 'cloudformation', 'list-stacks', '--region', region].execute() | 'grep -B5 CREATE_COMPLETE'.execute() | 'grep StackName'.execute() | ['awk', '{print $2}'].execute() | ['tr', '-d', '"\\"\\|,\\|\\{\\|\\\\["'].execute()
        p.waitFor()
        p.text.eachLine { line ->
					output << line
        }
        output.each {
            println it
        }
