# **JQ examples**

### Display colored results:

`aws ec2 describe-instances | jq `

### Display only the N element in array:

`aws ec2 describe-instances | jq '.Reservations[]?.Instances | .[0]'`

### Drill down into the JSON:

`aws ec2 describe-instances | jq '.Reservations[].Instances[].InstanceType'`

### Drill down into JSON, display output in raw mode:

`aws ec2 describe-instances | jq -r '.Reservations[].Instances[].InstanceType'`

### Display all the Values of a Key:

`aws ec2 describe-instances | jq '.Reservations[]?.Instances[].NetworkInterfaces[].PrivateIpAddresses[] | .[]'`

### Display all the Values where the Key contains "DOCKERVERSION":

`aws ec2 describe-instances | jq -r '.Reservations[].Instances[].Tags[] | select(.Key | contains("DOCKERVERSION")).Value'`

### Display all the Values where the Key eqauls "Name":

`aws ec2 describe-vpcs --region us-east-1 | jq -r '.Vpcs[].Tags[] | select(.Key=="Name") | .Value'`

### Searching for a Name where the value starts with "staging":

`aws route53 list-resource-record-sets --hosted-zone-id $zoneId | jq -r '.ResourceRecordSets[]? | select(.ResourceRecords[]?.Value | startswith("staging")) | .Name'`

### Supplying a variable to jq:

`jq --arg varName varValue ''`

### Supplying a variable to jq as the search pattern:

`aws route53 list-resource-record-sets --hosted-zone-id $zoneId | jq -r --arg pattern $newStgRenderer '.ResourceRecordSets[]? | select(.ResourceRecords[]?.Value | contains($pattern)) | .Name'`

### Map an object to arrays:

`aws ec2 describe-instances | jq -r '.Reservations[].Instances[].SecurityGroups[] | to_entries[] | [.key, .value]'`

Example output:

> [
> > "GroupName",
> > "ALLOW-SSH-FROM-OFFICE"
> > ] > [
> > "GroupId",
> > "sg-f24XXX88"
> > ]

### Transforming jq output:

`aws ec2 describe-instances | jq ".Reservations[].Instances[] | { VpcId: .VpcId , SubnetId: .SubnetId}"`

Example output:

> {
> "VpcId": "vpc-de5xxx9",
> "SubnetId": "subnet-cxxx65ef"
> }
> {
> "VpcId": "vpc-de5xxx9",
> "SubnetId": "subnet-xxxbce3f"
> }

### Transform using specific element in array (in this case, the first one):

`jq '.[0] | { Author: .author.login, Url: .committer.url}'`

Example:

`curl -s 'https://api.github.com/repos/geek-kb/DevopsStuff/commits?per_page=5' | jq '.[0] | { Author: .author.login, Url: .committer.url}'`

Example output:

> {
> "Author": "geek-kb",
> "Url": "https://api.github.com/users/geek-kb"
> }

### Display all AWS EC2 InstanceIds where Instance contains a Name Tag which matches "jenkins" (case insensitive):

> aws ec2 describe-instances | jq -r '.Reservations[].Instances[] | select(.Tags[]?.Value | match("jenkins";"i")) | .InstanceId'

### Display a security group's list of rules and format it as: FromPort (if exists) to ToPort (if exists) transformed to strings so I'd be able to add a dash between the values which can be done only with strings. In addition also display protocol name and source cidr or security group, format the output as "Tab Separated Value".

> aws ec2 describe-security-groups --group-id ${group_id} --profile ${profile} --region ${region} --output json | jq -r '.SecurityGroups[].IpPermissions[] | [ ((.FromPort // "")|tostring)+" - "+((.ToPort // "")|tostring), .IpProtocol, .IpRanges[].CidrIp // .UserIdGroupPairs[].GroupId // "" ] | @tsv'

Example output:

> 10000 - 10100 tcp 10.200.120.0/24 10.200.130.0/24

> 8081 - 8120 tcp 10.200.120.0/24 10.200.130.0/24

> 5432 - 5432 tcp sg-0e73b6cca3a6a83d2

### Display a list of instances attached to a given security group, format it as a tab separated table with values that indicate the instance's id, state, launch time and name, parsed from Tag called "Name":

> aws ec2 describe-instances --filters "Name=instance.group-id,Values=${group_id}" --profile ${profile} --region ${region} --output json | jq -r '.Reservations[].Instances[] | [ .InstanceId, .State.Name, .LaunchTime, (.Tags[] | select(.Key=="Name").Value) ] | @tsv'

Example output:

> i-098c5d63a3edb3629 running 2020-04-05T11:27:01+00:00 k8s-prod-eu-west-1-worker-eks_asg
> <br><br>

### Extracting a value of all CloudFormation stacks which match specific string in key Stackname and StackStatus of "CREATE COMPLETE" or "UPDATE_COMPLETE":

> aws cloudformation list-stacks --profile production | jq -r '.StackSummaries[] | select(.StackName == "some-stack-name" and ( .StackStatus == "CREATE_COMPLETE" or .StackStatus == "UPDATE_COMPLETE" )) | .StackId'

Example output:

> arn:aws:cloudformation:us-east-1:AWS_ACCOUNT_ID:stack/some-stack-name/44239210-9703-11eb-b085-12da3ecd6186

### Extracting db snapshot identifier, db snapshot arn and db snapshot create time based on a specific date (2022-05-13)

> aws rds describe-db-snapshots --db-instance-identifier production-company-rds01 --region us-east-2 | jq --arg snapshot_date 2022-05-13 -r '.DBSnapshots[] | select((.DBSnapshotIdentifier | startswith("production-company-rds01") and (.OriginalSnapshotCreateTime | startswith($snapshot_date))) | "OriginalSnapshotCreateTime="+.OriginalSnapshotCreateTime, "DBSnapshotArn="+.DBSnapshotArn, "DBSnapshotIdentifier="+.DBSnapshotIdentifier'

Example output:

> OriginalSnapshotCreateTime=2022-05-13T07:06:44.974000+00:00

> DBSnapshotArn=arn:aws:rds:us-east-2:ACCOUNT_ID:snapshot:rds:production-company-rds-01-2022-05-13-07-06

> DBSnapshotIdentifier=rds:production-company-rds01-2022-05-13-07-06

# **Troubleshooting:**

### Sometimes, when not all elements have keys, the following error will be shown:

`jq: error (at <stdin>:52243): Cannot iterate over null (null)`
<br><br>
Example:
<br><br>
`aws ec2 describe-instances | jq ".Reservations[].Instances[] | {VirtualizationType: .VirtualizationType , Tags: .Tags[]}" | tail -5`

> jq: error (at <stdin>:52243): Cannot iterate over null (null)
> "Tags": {
> "Key": "SWARM_TYPE",
> "Value": "Production"
> }
> }

In order to supress this error, add a question mark after the key which doesn't exist in all elements, in this case "Tags".
<br><br>
Example:
<br><br>
`aws ec2 describe-instances | jq ".Reservations[].Instances[] | {VirtualizationType: .VirtualizationType , Tags: .Tags[]?}" | tail -5`

> "Tags": {
> "Key": "SWARM_TYPE",
> "Value": "Production"
> }
> }

<br><br>

Maintained by: Itai Ganot, lel@lel.bz
