#!/bin/bash

pushd /home/ubuntu > /dev/null

if [ -d "persistent-hdfs" ]; then
  echo "Persistent HDFS seems to be installed. Exiting."
  return 0
fi

case "$HADOOP_MAJOR_VERSION" in
  1)
    wget http://s3.amazonaws.com/spark-related-packages/hadoop-1.0.4.tar.gz
    echo "Unpacking Hadoop"
    tar xvzf hadoop-1.0.4.tar.gz > /tmp/spark-ec2_hadoop.log
    rm hadoop-*.tar.gz
    mv hadoop-1.0.4/ persistent-hdfs/
    ;;
  2)
    wget http://s3.amazonaws.com/spark-related-packages/hadoop-2.0.0-cdh4.2.0.tar.gz  
    echo "Unpacking Hadoop"
    tar xvzf hadoop-*.tar.gz > /tmp/spark-ec2_hadoop.log
    rm hadoop-*.tar.gz
    mv hadoop-2.0.0-cdh4.2.0/ persistent-hdfs/

    # Have single conf dir
    #rm -rf /home/ubuntu/persistent-hdfs/etc/hadoop/
    ln -s /home/ubuntu/persistent-hdfs/conf /home/ubuntu/persistent-hdfs/etc/hadoop
    ;;

  *)
     echo "ERROR: Unknown Hadoop version"
     return -1
esac
cp /home/ubuntu/hadoop-native/* persistent-hdfs/lib/native/
/home/ubuntu/spark-ec2/copy-dir /home/ubuntu/persistent-hdfs

popd > /dev/null
