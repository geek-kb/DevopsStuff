ArrayList subnets_list = []
output = "/var/lib/jenkins/build_shell_scripts/get_subnetid_by_cidr.sh $Region $SubnetCidr".execute()
output.waitFor()
subnets_list = output.text.split()
return subnets_list.sort()
