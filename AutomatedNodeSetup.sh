#!/bin/bash

# Check if two arguments are provided
if [ $# -ne 2 ]; then
    echo "Please enter hostname and IP address as arguments."
    exit 1
fi

# Arguments
NODE_HOSTNAME="$1"
NODE_IP="$2"

# Configuration
SERVER_IP=192.168.56.101
SERVER_USER=root

# Update the /etc/hosts file to include the head node and both compute nodes' IP addresses.
echo "-------------------- [INFO] Setting hostname and updating /etc/hosts --------------------"
hostnamectl set-hostname "$NODE_HOSTNAME"


IPADDR=$NODE_IP
IFACE="enp0s3"
CONFIG="/etc/sysconfig/network-scripts/ifcfg-$IFACE"

cat <<EOF | sudo tee $CONFIG > /dev/null
TYPE=Ethernet
BOOTPROTO=none
NAME=$IFACE
DEVICE=$IFACE
ONBOOT=yes
IPADDR=$IPADDR
NETMASK=255.255.255.0
GATEWAY=192.168.1.1
DNS1=8.8.8.8
EOF

sudo systemctl restart network


echo "-------------------- [INFO] Updating /etc/hosts --------------------"
echo "$NODE_IP $NODE_HOSTNAME" >> /etc/hosts

echo "-------------------- [INFO] Adding node to server's /etc/hosts --------------------"
ssh $SERVER_USER@$SERVER_IP "grep -q '$NODE_IP $NODE_HOSTNAME' /etc/hosts || echo '$NODE_IP $NODE_HOSTNAME' >> /etc/hosts"

echo "-------------------- [INFO] Getting updated /etc/hosts from server --------------------"

# Get the updated hosts file from server
scp $SERVER_USER@$SERVER_IP:/etc/hosts /etc/hosts


# Generate or copy an SSH public key from the head node and place it in the 
# compute node’s ~/.ssh/authorized_keys file for passwordless login.
echo "-------------------- [INFO] Setting up passwordless SSH access --------------------"

sudo -u user1 bash <<EOF
# Generate key if not already present
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa -q
    echo "SSH key generated"
fi

# Copy public key to server's user1 account
ssh-copy-id -o StrictHostKeyChecking=no user1@$SERVER_IP
EOF


# Install NFS utilities and mount the shared directory (e.g., /ddn) from the head node. Ensure the mount is persistent by updating /etc/fstab.
echo "-------------------- [INFO] Mounting shared NFS directory --------------------"
sudo yum install -y nfs-utils
mkdir -p /ddn
if ! grep -q "/ddn" /etc/fstab; then
    echo "$SERVER_IP:/ddn    /ddn    nfs     defaults,_netdev    0 0" >> /etc/fstab
fi
mount -a

# 5. Disable firewall and SELinux
echo "-------------------- [INFO] Disabling firewall and SELinux --------------------"
systemctl stop firewalld
systemctl disable firewalld


# Install the PBS MOM package (e.g., pbspro-execution) using your package manager (e.g.,yum).
yum install -y /pbspro_19.1.3.centos_7/pbspro-execution-19.1.3-0.x86_64.rpm
yum install -y environment-modules

# Disable SELinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

# Configure PBS by adding the head node’s hostname into the MOM configuration file:/var/spool/pbs/mom_priv/config.
echo "-------------------- [INFO] Configuring PBS MOM --------------------"
sed -i 's/PBS_SERVER=.*/PBS_SERVER=server/' /etc/pbs.conf
echo "\$clienthost server" > /var/spool/pbs/mom_priv/config

pkill -f pbs_mom
/opt/pbs/libexec/pbs_postinstall

# Enable and start the PBS service using systemctl: systemctl enable pbs && systemctl start pbs.
echo "-------------------- [INFO] Enabling and starting PBS --------------------"
systemctl daemon-reload
systemctl enable pbs
sleep 3
systemctl start pbs


echo " Node $NODE_HOSTNAME ($NODE_IP) setup completed!"
