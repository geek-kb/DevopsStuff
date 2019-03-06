ArrayList subnets_list = []
output = "/var/lib/jenkins/build_shell_scripts/describe_subnets_cidrs_ec2.sh $Region $VpcName".execute()
output.waitFor()
subnets_list = output.text.split()
return subnets_list.sort()
