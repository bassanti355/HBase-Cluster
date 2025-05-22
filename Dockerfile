FROM ubuntu:22.04

# Install all dependencies in a single RUN command
RUN apt update -y && \
    apt upgrade -y && \
    apt install -y \
        openjdk-8-jdk \
        ssh \
        nano \
        sudo \
        curl \
        netcat && \
    rm -rf /var/lib/apt/lists/*
    

# User and environment setup
RUN echo "root:123" | chpasswd && \
    addgroup hadoop && \
    adduser --disabled-password --ingroup hadoop hadoop

# Set all environment variables in one ENV instruction
ENV HADOOP_HOME=/usr/local/hadoop \
    PATH=/usr/local/hadoop/bin:/usr/local/hadoop/\
    JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 \
    HDFS_NAMENODE_USER=hadoop \
    HDFS_DATANODE_USER=hadoop \
    HDFS_SECONDARYNAMENODE_USER=hadoop \
    YARN_RESOURCEMANAGER_USER=hadoop \
    YARN_NODEMANAGER_USER=hadoop

# Hadoop installation and setup
ADD https://dlcdn.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz /tmp

# Use absolute paths instead of variables in RUN commands
RUN tar -xzf /tmp/hadoop-3.3.6.tar.gz -C /usr/local/ && \
    mv /usr/local/hadoop-3.3.6 /usr/local/hadoop && \
    rm -f /tmp/hadoop-3.3.6.tar.gz && \
    chown -R hadoop:hadoop /usr/local/hadoop && \
    chmod -R 777 /usr/local/hadoop

# Copy all Hadoop config files at once
COPY HadoopConfig/hadoop-env.sh HadoopConfig/core-site.xml HadoopConfig/hdfs-site.xml HadoopConfig/mapred-site.xml HadoopConfig/yarn-site.xml HadoopConfig/workers /usr/local/hadoop/etc/hadoop/
RUN chown -R hadoop:hadoop /usr/local/hadoop/etc/hadoop/


# Final setup
RUN echo "hadoop ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /var/run/sshd

USER hadoop
WORKDIR /home/hadoop

RUN mkdir -p /usr/local/hadoop/yarn_data/hdfs/namenode && \
    sudo mkdir -p /usr/local/backup/ && \
    sudo chmod -R 777 /usr/local/backup/ && \
    mkdir -p /usr/local/hadoop/yarn_data/hdfs/datanode && \
    mkdir -p /usr/local/hadoop/yarn_data/hdfs/journalnode && \
    chmod -R 777 /usr/local/hadoop/yarn_data/hdfs && \
    ssh-keygen -t rsa -f ~/.ssh/id_rsa -N "" && \
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && \
    chmod 600 ~/.ssh/authorized_keys && \
    echo "sudo /usr/sbin/sshd" >> ~/.bashrc

COPY HadoopConfig/entrypoint.sh /usr/local/hadoop/
RUN sudo chmod +x /usr/local/hadoop/entrypoint.sh && \
    sudo chown hadoop:hadoop /usr/local/hadoop/entrypoint.sh

ENTRYPOINT ["/usr/local/hadoop/entrypoint.sh"]