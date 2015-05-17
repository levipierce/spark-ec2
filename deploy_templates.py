#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import with_statement

import os
import sys

# Deploy the configuration file templates in the spark-ec2/templates directory
# to the root filesystem, substituting variables such as the master hostname,
# ZooKeeper URL, etc as read from the environment.

# Find system memory in KB and compute Spark's default limit from that
mem_command = "cat /proc/meminfo | grep MemTotal | awk '{print $2}'"
cpu_command = "nproc"

master_ram_kb = int(
  os.popen(mem_command).read().strip())
# This is the master's memory. Try to find slave's memory as well
first_slave = os.popen("cat /home/ubuntu/spark-ec2/slaves | head -1").read().strip()

slave_mem_command = "ssh -t -o StrictHostKeyChecking=no %s %s" %\
        (first_slave, mem_command)

slave_cpu_command = "ssh -t -o StrictHostKeyChecking=no %s %s" %\
        (first_slave, cpu_command)
try:
    slave_ram_kb = int(os.popen(slave_mem_command).read().strip())
except ValueError e:
    print "Value error({0}): {1}".format(e.errno, e.strerror)
    continue


try:
    slave_cpus = int(os.popen(slave_cpu_command).read().strip())

    system_ram_kb = min(slave_ram_kb, master_ram_kb)

    system_ram_mb = system_ram_kb / 1024
    # Leave some RAM for the OS, Hadoop daemons, and system caches
    if system_ram_mb > 100*1024:
      spark_mb = system_ram_mb - 15 * 1024 # Leave 15 GB RAM
    elif system_ram_mb > 60*1024:
      spark_mb = system_ram_mb - 10 * 1024 # Leave 10 GB RAM
    elif system_ram_mb > 40*1024:
      spark_mb = system_ram_mb - 6 * 1024 # Leave 6 GB RAM
    elif system_ram_mb > 20*1024:
      spark_mb = system_ram_mb - 3 * 1024 # Leave 3 GB RAM
    elif system_ram_mb > 10*1024:
      spark_mb = system_ram_mb - 2 * 1024 # Leave 2 GB RAM
    else:
      spark_mb = max(512, system_ram_mb - 1300) # Leave 1.3 GB RAM

except ValueError e:
    print "Value error({0}): {1}".format(e.errno, e.strerror)
    continue
else:
    spark_mb = 225

# Make tachyon_mb as spark_mb for now.
tachyon_mb = spark_mb

worker_instances = int(os.getenv("SPARK_WORKER_INSTANCES", 1))
# Distribute equally cpu cores among worker instances
worker_cores = max(slave_cpus / worker_instances, 1)

template_vars = {
  "master_list": os.getenv("MASTERS"),
  "active_master": os.getenv("MASTERS").split("\n")[0],
  "slave_list": os.getenv("SLAVES"),
  "hdfs_data_dirs": os.getenv("HDFS_DATA_DIRS"),
  "mapred_local_dirs": os.getenv("MAPRED_LOCAL_DIRS"),
  "spark_local_dirs": os.getenv("SPARK_LOCAL_DIRS"),
  "default_spark_mem": "%dm" % spark_mb,
  "spark_worker_instances": "%d" %  worker_instances,
  "spark_worker_cores": "%d" %  worker_cores,
  "spark_master_opts": os.getenv("SPARK_MASTER_OPTS", ""),
  "spark_version": os.getenv("SPARK_VERSION"),
  "tachyon_version": os.getenv("TACHYON_VERSION"),
  "hadoop_major_version": os.getenv("HADOOP_MAJOR_VERSION"),
  "java_home": os.getenv("JAVA_HOME"),
  "default_tachyon_mem": "%dMB" % tachyon_mb,
  "aws_access_key_id": os.getenv("AWS_ACCESS_KEY_ID"),
  "aws_secret_access_key": os.getenv("AWS_SECRET_ACCESS_KEY"),
}

template_dir="/home/ubuntu/spark-ec2/templates"

for path, dirs, files in os.walk(template_dir):
    #Skip svn files...
    if path.find(".svn") == -1:
        dest_dir = os.path.join('/', path[len(template_dir):])
        try:
            if not os.path.exists(dest_dir):
                os.makedirs(dest_dir)
        except OSError as e:
            print "OS error({0}): {1}".format(e.errno, e.strerror)
            continue
        for filename in files:
            if filename[0] not in '#.~' and filename[-1] != '~':
                dest_file = os.path.join(dest_dir, filename)
                with open(os.path.join(path, filename)) as src:
                    with open(dest_file, "w") as dest:
                        print "Configuring " + dest_file
                        text = src.read()
                        for key in template_vars:
                            text = text.replace("{{" + key + "}}", template_vars[key] or '')
                        dest.write(text)
                        dest.close()
