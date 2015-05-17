#!/bin/bash

# NOTE: Remove all rrds which might be around from an earlier run
sudo rm -rf /var/lib/ganglia/rrds/*
sudo rm -rf /mnt/ganglia/rrds/*

# Make sure rrd storage directory has right permissions
mkdir -p /mnt/ganglia/rrds
chown -R nobody:nobody /mnt/ganglia/rrds

# Install ganglia
# TODO: Remove this once the AMI has ganglia by default

# Post-package installation : Symlink /var/lib/ganglia/rrds to /mnt/ganglia/rrds
sudo rmdir /var/lib/ganglia/rrds
ln -s /mnt/ganglia/rrds /var/lib/ganglia/rrds
