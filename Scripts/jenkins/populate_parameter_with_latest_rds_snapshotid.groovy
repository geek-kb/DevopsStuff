#!/usr/local/bin/groovy
# Returns an array of latest available RDS Snapshot Ids per environment [ EnvDBNames ].
# Can be used to populate a parameter in Jenkins + Extended Parameter plugin.
# Script by Itai Ganot 2017
String todayDate = new Date().format( 'yyyy-MM-dd' )
def EnvDBNames = ['dev-rds', 'stg-rds', 'prd-rds']
retval=[]
EnvDBNames.each {
	def rdbs = "aws rds describe-db-snapshots --db-instance-identifier ${it} --snapshot-type automated --query DBSnapshots[?SnapshotCreateTime>='$todayDate'].DBSnapshotIdentifier".execute().text.eachLine {
		if (!it.contains(']') && (!it.contains('[') ) )
			retval.add(it.replaceAll('\"','').trim())
	}
}

retval.each {
	println it
}
