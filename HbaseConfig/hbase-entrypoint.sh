#!/bin/bash

echo "HBASE_HOME is $HBASE_HOME"
echo "Looking for $HBASE_HOME/bin/hbase-daemon.sh"

# Debug output to help us verify contents
ls -l $HBASE_HOME
ls -l $HBASE_HOME/bin

hdfs dfs -mkdir -p /hbase
hdfs dfs -chown hbase:hbase /hbase

# Initialize environment
source $HBASE_HOME/conf/hbase-env.sh



# Start appropriate service based on role
if [ "$HBASE_ROLE" = "master" ]; then
  echo "Starting HBase Master"
  $HBASE_HOME/bin/hbase master start
elif [ "$HBASE_ROLE" = "regionserver" ]; then
  echo "Starting HBase RegionServer"
  $HADOOP_HOME/bin/hdfs --daemon start datanode
  $HADOOP_HOME/bin/yarn --daemon start nodemanager
  $HBASE_HOME/bin/hbase-daemon.sh start regionserver

fi

# Keep container running
tail -f /dev/null



