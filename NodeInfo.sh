#!/bin/bash

# Configuration
HOSTNAME=$(hostname)
OUTPUTFILE="${HOSTNAME}_status.log"

{
    echo "Node Information Report"
    echo "------------------------"
    echo "Hostname        : $HOSTNAME"
    echo "IP Address      : $(hostname -I | awk '{print $1}')"
    echo "OS Version      : $(cat /etc/centos-release)"
    echo "Kernel Version  : $(uname -r)"
    echo "CPU Cores       : $(lscpu | awk '/^CPU\(s\):/ {print $2}')"
    echo "Total RAM       : $(awk '/MemTotal/ {printf "%.2f", $2/1048576}' /proc/meminfo) GB"
    echo "Disk Usage      : $(df -h / | awk 'NR==2 {print $5}') used on /"
    echo "PBS MOM Status  : $(systemctl is-active pbs) ($(systemctl is-enabled pbs))"
} > "$OUTPUTFILE"