#!/bin/bash

/home/ubuntu/spark-ec2/copy-dir /home/ubuntu/tachyon

/home/ubuntu/tachyon/bin/tachyon format

sleep 1

/home/ubuntu/tachyon/bin/tachyon-start.sh all Mount
