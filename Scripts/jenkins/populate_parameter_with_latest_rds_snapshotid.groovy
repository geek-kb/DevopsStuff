#!/usr/local/bin/groovy
# Returns an array of latest available RDS Snapshot Ids per environment [ EnvDBNames ].
# Can be used to populate a parameter in Jenkins + Extended Parameter plugin.
# Script by Itai Ganot 2017
region = 'eu-west-1'
String todayDate = new Date().format( 'yyyy-MM-dd' )
retval=[]
def rdbs = "aws rds describe-db-snapshots --snapshot-type manual --query DBSnapshots[?SnapshotCreateTime>='$todayDate'].DBSnapshotIdentifier --region $region".execute().text.eachLine {
  if (!it.contains(']') && (!it.contains('[') ) )
    retval.add(it.replaceAll('\"','').trim())
}

retval.each {
   println it
}
