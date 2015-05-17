#!/bin/bash

BIN_FOLDER="/home/ubuntu/spark/sbin"

if [[ "0.7.3 0.8.0 0.8.1" =~ $SPARK_VERSION ]]; then
  BIN_FOLDER="/home/ubuntu/spark/bin"
fi

# Copy the slaves to spark conf
cp /home/ubuntu/spark-ec2/slaves /home/ubuntu/spark/conf/
/home/ubuntu/spark-ec2/copy-dir /home/ubuntu/spark/conf

# Set cluster-url to standalone master
echo "spark://""`cat /home/ubuntu/spark-ec2/masters`"":7077" > /home/ubuntu/spark-ec2/cluster-url
/home/ubuntu/spark-ec2/copy-dir /home/ubuntu/spark-ec2

# The Spark master seems to take time to start and workers crash if
# they start before the master. So start the master first, sleep and then start
# workers.

# Stop anything that is running
$BIN_FOLDER/stop-all.sh

sleep 2

# Start Master
$BIN_FOLDER/start-master.sh

# Pause
sleep 20

# Start Workers
$BIN_FOLDER/start-slaves.sh
