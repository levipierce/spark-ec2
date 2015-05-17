#!/bin/bash

pushd /home/ubuntu > /dev/null

if [ -d "ephemeral-hdfs" ]; then
  echo "Ephemeral HDFS seems to be installed. Exiting."
  return 0
fi

case "$HADOOP_MAJOR_VERSION" in
  1)
    echo "Nothing to initialize for MapReduce in Hadoop 1"
    ;;
  2) 
    wget http://s3.amazonaws.com/spark-related-packages/hadoop-2.0.0-cdh4.2.0.tar.gz  
    echo "Unpacking Hadoop"
    tar xvzf hadoop-*.tar.gz > /tmp/spark-ec2_hadoop.log
    rm hadoop-*.tar.gz
    mv hadoop-2.0.0-cdh4.2.0/ ephemeral-hdfs/

    # Have single conf dir
    #rm -rf /home/ubuntu/ephemeral-hdfs/etc/hadoop/
    ln -s /home/ubuntu/ephemeral-hdfs/conf /home/ubuntu/ephemeral-hdfs/etc/hadoop
    ;;

  *)
     echo "ERROR: Unknown Hadoop version"
     return -1
esac
cp /home/ubuntu/hadoop-native/* ephemeral-hdfs/lib/native/
/home/ubuntu/spark-ec2/copy-dir /home/ubuntu/ephemeral-hdfs

popd > /dev/null
