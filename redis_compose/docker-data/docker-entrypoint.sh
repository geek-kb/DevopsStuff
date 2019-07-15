#!/bin/sh

if [ "$1" = 'redis-cluster' ]; then
    sleep 10
    echo "yes" | ruby /redis/src/redis-trib.rb create --replicas 1 173.17.0.2:30001 173.17.0.3:30002 173.17.0.4:30003 173.17.0.5:30004 173.17.0.6:30005 173.17.0.7:30006
#    echo "yes" | ruby /redis/src/redis-trib.rb create --replicas 1 173.17.0.1:30001 173.17.0.2:30002 173.17.0.3:30003 173.17.0.4:30004 173.17.0.5:30005 173.17.0.6:30006
    echo "DONE"
else
  exec "$@"
fi
