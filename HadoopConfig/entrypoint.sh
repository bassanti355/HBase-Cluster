#!/usr/bin/env bash

# Start SSH service
sudo service ssh start
sudo chmod 777 /usr/local/hadoop/yarn_data/hdfs/datanode 

# Only run ZooKeeper and NameNode initialization on master nodes

if hostname | grep -q "master"; then

    # Write ZooKeeper myid (corrected path)
    echo ${ZK_ID} > /usr/local/zookeeper/data/myid 
    echo "ZooKeeper ID set to ${ZK_ID}"
    
    
    
    # Initialize JournalNode (all masters)
    hdfs --daemon start journalnode
    
    # Start ZooKeeper (all masters)
    zkServer.sh start
    
    
    # Special initialization for first master
    if [ "$ZK_ID" = "1" ] ; then

        if  [ ! -f /usr/local/hadoop/data/namenode/current/VERSION ]; then
            echo "First time running, formatting namenode"
            
            # Initialize ZKFC
            hdfs zkfc -formatZK -force
            
            # Format NameNode
            hdfs namenode -format -force
        fi     
            # Start NameNode
            hdfs --daemon start namenode
            
        
            
        # Standby NameNode initialization
    else
    
        if  [ ! -f /usr/local/hadoop/data/namenode/current/VERSION ]; then
            echo "First time running, formatting standbyde"
            echo "Initializing standby namenode"
            hdfs namenode -bootstrapStandby -force
        fi


    
        # Normal startup if already initialized
        hdfs --daemon start namenode
    fi


    # Start ZKFC
    hdfs --daemon start zkfc    
    # Start ResourceManager
    yarn --daemon start resourcemanager

else
    # Worker node startup
    hdfs --daemon start datanode
    yarn --daemon start nodemanager

fi

# Keep the container running
sleep infinity