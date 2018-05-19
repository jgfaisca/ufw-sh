#!/bin/bash
#
##
## DESCRIPTION: Add NAT port forwarding to linux ufw firewall configuration
##
## USAGE:
## $ ./nat-port-forwarding-ufw.sh <network_interface> <port> <tcp/udp> <ip_address>
##
## USAGE EXAMPLE:
## $ sudo ./nat-port-forwarding-ufw.sh enp2s0f1 32768 tcp 10.107.73.39
##
##
## AUTHOR: Jose G. Faisca Â
## <jose.faisca@gmail.com>
##
## DATE: 2018.05.18
##
## VERSION: 0.1
##

# Validate protocol
function validProtocol() {
    case "$1" in
    "tcp"|"udp")
        return 0;;
    *)
        return 1;;
    esac
}

# Validate IP address
function validIP(){
    local  ip=$1
    local  stat=1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# Set firewall
function setFirewall() {
  ufw allow $1/$2
  systemctl restart ufw
  #ufw status
  #iptables -t nat -L -n -v
}

# Check permissions
if [[ $EUID > 0 ]]; then
  echo "Please run as root/sudo"
  exit 1
fi

ARGS="valid"
DIR="/etc/ufw"
FILENAME="before.rules"

# Check arguments
if [ "$#" -ne 4 ]; then
   echo "usage: $0 <network_interface> <port> <tcp/udp> <ip_address>"
   exit 2
fi

# Arguments
NETWORK_INTERFACE="$1"
PORT="$2"
PROTOCOL=$(echo "$3" | tr '[:upper:]' '[:lower:]')
IP_ADDRESS="$4"

if ! validProtocol $PROTOCOL; then
    ARGS="invalid"
    echo "Protocol $PROTOCOL is invalid."
fi

if ! validIP $IP_ADDRESS; then
    ARGS="invalid"
    echo "IP address $IP_ADDRESS is invalid."
fi

if [ "$ARGS" = "invalid" ]; then
    exit 2
fi

# Create port forward line
VAR="-A PREROUTING -i ${NETWORK_INTERFACE} -p ${PROTOCOL} --dport \
${PORT} -j DNAT --to-destination ${IP_ADDRESS}"

# Print port forward line
echo $VAR

# Get configuration mark from mark.txt file
MARK=$(grep "." mark.txt | tail -1)

# Add mark to configuration file before first COMMIT line
if ! grep -Fxqe "$MARK" $DIR/$FILENAME ; then
   CMD="printf '0,/COMMIT/-1 r mark.txt\n,w\nq' | ed -s ${DIR}/${FILENAME}"
   eval $CMD
fi

# Check if port forwarding line already exists
if grep -Fxqe "$VAR" $DIR/$FILENAME; then
   echo "[ERROR 3] Port forwarding already configured."
   exit 3
fi

# Add port forwarding line to configuration file
sed "/^${MARK}/a\
$VAR" $DIR/$FILENAME > $DIR/tmp_$FILENAME
mv $DIR/tmp_$FILENAME $DIR/$FILENAME

# Final setup
if grep -Fxqe "$VAR" $DIR/$FILENAME; then
    setFirewall $PORT $PROTOCOL
    echo "[OK] Port forwarding configured succesfully."
    exit 0
else
    echo "[ERROR 4] Port forwarding configuration failed."
    exit 4
fi

