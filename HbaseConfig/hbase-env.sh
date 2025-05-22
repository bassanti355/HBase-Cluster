export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HBASE_MANAGES_ZK=false
export HBASE_LOG_DIR=/var/log/hbase
export HBASE_OPTS="$HBASE_OPTS -Dhbase.regionserver.hostname=$(hostname -s)"