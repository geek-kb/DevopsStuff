ArrayList keypair_list = []
output = "/var/lib/jenkins/build_shell_scripts/list_keypairs_ec2.sh $Region".execute()
output.waitFor()
keypair_list = output.text.split()
return keypair_list
