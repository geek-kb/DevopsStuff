ArrayList vpcnames_list = []
output = "/var/lib/jenkins/build_shell_scripts/get_vpcs_name.sh $Region".execute()
output.waitFor()
vpcnames_list = output.text.split()
return vpcnames_list
