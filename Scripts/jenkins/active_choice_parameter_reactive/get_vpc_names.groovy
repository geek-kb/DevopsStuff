#!/usr/local/bin/groovy
ArrayList vpcnames_list = []
output = "/Users/iganot/src/personal/DevopsStuff/Scripts/jenkins/active_choice_parameter_reactive/get_vpcs_name.sh".execute()
output.waitFor()
vpcnames_list = output.text.split()
return vpcnames_list
