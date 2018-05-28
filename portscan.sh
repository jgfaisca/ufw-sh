#!/bin/bash
#
# Port scan (UDP and TCP) using nmap
#

if [ "$#" -ne 2 ]; then
    echo "Usage: "$0" <port(0)-port(n)> <host>"
    exit 1
fi

PORTS=$1
HOST=$2
sudo nmap -sU -sT -p$PORTS $HOST
