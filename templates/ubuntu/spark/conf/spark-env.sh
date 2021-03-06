#!/usr/bin/env bash

export SPARK_LOCAL_DIRS="{{spark_local_dirs}}"

# Standalone cluster options
export SPARK_MASTER_OPTS="{{spark_master_opts}}"
export SPARK_WORKER_INSTANCES={{spark_worker_instances}}
export SPARK_WORKER_CORES={{spark_worker_cores}}

export HADOOP_HOME="/home/ubuntu/ephemeral-hdfs"
export SPARK_MASTER_IP={{active_master}}
export MASTER=`cat /home/ubuntu/spark-ec2/cluster-url`

export SPARK_SUBMIT_LIBRARY_PATH="$SPARK_SUBMIT_LIBRARY_PATH:/home/ubuntu/ephemeral-hdfs/lib/native/"
export SPARK_SUBMIT_CLASSPATH="$SPARK_CLASSPATH:$SPARK_SUBMIT_CLASSPATH:/home/ubuntu/ephemeral-hdfs/conf"

# Bind Spark's web UIs to this machine's public EC2 hostname otherwise fallback to private IP:
SPARK_PUBLIC_DNS=`wget -q -O - http://169.254.169.254/latest/meta-data/public-hostname`
if [[ -z "$SPARK_PUBLIC_DNS" ]]; then
  SPARK_PUBLIC_DNS=`wget -q -O - http://169.254.169.254/latest/meta-data/local-ipv4`
fi
export SPARK_PUBLIC_DNS

# Set a high ulimit for large shuffles
sudo bash -c "ulimit -n 1000000"
