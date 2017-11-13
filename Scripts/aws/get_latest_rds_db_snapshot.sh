#!/bin/bash -xe
env=${env}
todaydate=$(date +"%Y-%m-%d")
region="us-west-2"
case $env in
  dev)
    dbname="dev-rds-2017-10-02"
  ;;
  stg)
    dbname="angelsense"
  ;;
  prd)
    dbname="prod"
  ;;
  *)
    echo "Unknown environment!"
    exit 1
  ;;
esac
LATESTRDSDBSNAPSHOT=$(aws rds describe-db-snapshots --db-instance-identifier $dbname --snapshot-type automated --query "DBSnapshots[?SnapshotCreateTime>='$todaydate'].DBSnapshotIdentifier" | grep rds | tr -d '\"|[:space:]')
echo "RDSSnapshotID=$LATESTRDSDBSNAPSHOT" > env.properties
