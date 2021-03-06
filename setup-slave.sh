#!/bin/bash

# Disable Transparent Huge Pages (THP)
# THP can result in system thrashing (high sys usage) due to frequent defrags of memory.
# Most systems recommends turning THP off.
#if [[ -e /sys/kernel/mm/transparent_hugepage/enabled ]]; then
#  echo never > /sys/kernel/mm/transparent_hugepage/enabled
#fi

# Make sure we are in the spark-ec2 directory
pushd /home/ubuntu/spark-ec2 > /dev/null

source /home/ubuntu/spark-ec2/ec2-variables.sh

# Set hostname based on EC2 private DNS name, so that it is set correctly
# even if the instance is restarted with a different private DNS name
PRIVATE_DNS=`wget -q -O - http://169.254.169.254/latest/meta-data/local-hostname`
sudo hostname $PRIVATE_DNS
sudo bash -c "echo $PRIVATE_DNS > /etc/hostname"
HOSTNAME=$PRIVATE_DNS  # Fix the bash built-in hostname variable too

echo "checking/fixing resolution of hostname"
bash /home/ubuntu/spark-ec2/resolve-hostname.sh

# Work around for R3 or I2 instances without pre-formatted ext3 disks
instance_type=$(curl http://169.254.169.254/latest/meta-data/instance-type 2> /dev/null)

echo "Setting up slave on `hostname`... of type $instance_type"

if [[ $instance_type == m3* || $instance_type == r3* || $instance_type == i2* || $instance_type == hi1* ]]; then
  # Format & mount using ext4, which has the best performance among ext3, ext4, and xfs based
  # on our shuffle heavy benchmark
  EXT4_MOUNT_OPTS="defaults,noatime,nodiratime"
  sudo rm -rf /mnt*
  sudo mkdir /mnt
  # To turn TRIM support on, uncomment the following line.
  #echo '/dev/sdb /mnt  ext4  defaults,noatime,nodiratime,discard 0 0' >> /etc/fstab
  sudo mkfs.ext4 -E lazy_itable_init=0,lazy_journal_init=0 /dev/xvdb
  sudo mount -o $EXT4_MOUNT_OPTS /dev/xvdb /mnt

  if [[ $instance_type == "m3.2xlarge" || $instance_type == "r3.8xlarge" || $instance_type == "hi1.4xlarge" ]]; then
    sudo mkdir /mnt2
    # To turn TRIM support on, uncomment the following line.
    #echo '/dev/sdc /mnt2  ext4  defaults,noatime,nodiratime,discard 0 0' >> /etc/fstab
    if [[ $instance_type == "r3.8xlarge" || $instance_type == "m3.2xlarge" ]]; then
      sudo mkfs.ext4 -E lazy_itable_init=0,lazy_journal_init=0 /dev/xvdc
      sudo mount -o $EXT4_MOUNT_OPTS /dev/xvdc /mnt2
    fi
    # To turn TRIM support on, uncomment the following line.
    #echo '/dev/sdf /mnt2  ext4  defaults,noatime,nodiratime,discard 0 0' >> /etc/fstab
    if [[ $instance_type == "hi1.4xlarge" ]]; then
      sudo mkfs.ext4 -E lazy_itable_init=0,lazy_journal_init=0 /dev/sdf      
      sudo mount -o $EXT4_MOUNT_OPTS /dev/sdf /mnt2
    fi    
  fi
fi

# Mount options to use for ext3 and xfs disks (the ephemeral disks
# are ext3, but we use xfs for EBS volumes to format them faster)
XFS_MOUNT_OPTS="defaults,noatime,nodiratime,allocsize=8m"

function setup_ebs_volume {
  device=$1
  mount_point=$2
  if [[ -e $device ]]; then
    # Check if device is already formatted
    if ! blkid $device; then
      sudo mkdir $mount_point
      if mkfs.xfs -q $device; then
        sudo mount -o $XFS_MOUNT_OPTS $device $mount_point
        sudo chmod -R a+w $mount_point
      else
        # mkfs.xfs is not installed on this machine or has failed;
        # delete /vol so that the user doesn't think we successfully
        # mounted the EBS volume
        sudo rmdir $mount_point
      fi
    else
      # EBS volume is already formatted. Mount it if its not mounted yet.
      if ! grep -qs '$mount_point' /proc/mounts; then
        sudo mkdir $mount_point
        sudo mount -o $XFS_MOUNT_OPTS $device $mount_point
        sudo chmod -R a+w $mount_point
      fi
    fi
  fi
}

# Format and mount EBS volume (/dev/sd[s, t, u, v, w, x, y, z]) as /vol[x] if the device exists
setup_ebs_volume /dev/sds /vol0
setup_ebs_volume /dev/sdt /vol1
setup_ebs_volume /dev/sdu /vol2
setup_ebs_volume /dev/sdv /vol3
setup_ebs_volume /dev/sdw /vol4
setup_ebs_volume /dev/sdx /vol5
setup_ebs_volume /dev/sdy /vol6
setup_ebs_volume /dev/sdz /vol7

# Alias vol to vol3 for backward compatibility: the old spark-ec2 script supports only attaching
# one EBS volume at /dev/sdv.
if [[ -e /vol3 && ! -e /vol ]]; then
  sudo ln -s /vol3 /vol
fi

# Make data dirs writable by non-home/ubuntu users, such as CDH's hadoop user
sudo chmod -R a+w /mnt*

# Remove ~/.ssh/known_hosts because it gets polluted as you start/stop many
# clusters (new machines tend to come up under old hostnames)
sudo rm -f /home/ubuntu/.ssh/known_hosts

# Create swap space on /mnt
sudo /home/ubuntu/spark-ec2/create-swap.sh $SWAP_MB

# Allow memory to be over committed. Helps in pyspark where we fork
sudo bash -c "echo 1 > /proc/sys/vm/overcommit_memory"

# Add github to known hosts to get git@github.com clone to work
# TODO(shivaram): Avoid duplicate entries ?
cat /home/ubuntu/spark-ec2/github.hostkey >> /home/ubuntu/.ssh/known_hosts

# Create /usr/bin/realpath which is used by R to find Java installations
# NOTE: /usr/bin/realpath is missing in CentOS AMIs. See
# http://superuser.com/questions/771104/usr-bin-realpath-not-found-in-centos-6-5
sudo bash -c "echo '#!/bin/bash' > /usr/bin/realpath"
sudo bash -c "echo 'readlink -e \"$@\"' >> /usr/bin/realpath"
sudo chmod a+x /usr/bin/realpath


popd > /dev/null
