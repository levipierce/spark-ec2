#!/bin/bash

/home/ubuntu/spark-ec2/copy-dir /etc/ganglia/

# Start gmond everywhere
sudo /etc/init.d/gmond restart

for node in $SLAVES $OTHER_MASTERS; do
  ssh -t -t $SSH_OPTS ubuntu@$node "/etc/init.d/gmond restart"
done

# gmeta needs rrds to be owned by nobody
chown -R ubuntu /var/lib/ganglia/rrds
# cluster-wide aggregates only show up with this. TODO: Fix this cleanly ?
ln -s /usr/share/ganglia/conf/default.json /var/lib/ganglia/conf/

sudo /etc/init.d/gmetad restart

# Start http server to serve ganglia
sudo /etc/init.d/httpd restart
