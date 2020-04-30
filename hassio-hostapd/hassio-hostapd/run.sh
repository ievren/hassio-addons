#!/bin/bash

CONFIG_PATH=/data/options.json

SSID=$(jq --raw-output ".ssid" $CONFIG_PATH)
WPA_PASSPHRASE=$(jq --raw-output ".wpa_passphrase" $CONFIG_PATH)
CHANNEL=$(jq --raw-output ".channel" $CONFIG_PATH)
ADDRESS=$(jq --raw-output ".address" $CONFIG_PATH)
NETMASK=$(jq --raw-output ".netmask" $CONFIG_PATH)
BROADCAST=$(jq --raw-output ".broadcast" $CONFIG_PATH)
HIDEAP=$(jq --raw-output ".hide_ap" $CONFIG_PATH)
INTERFACE=$(jq --raw-output ".interface" $CONFIG_PATH)

# SIGTERM-handler this funciton will be executed when the container receives the SIGTERM signal (when stopping)
term_handler(){
	echo "Stopping..."
	ifdown INTERFACE
	ip link set INTERFACE down
	ip addr flush dev INTERFACE
	exit 0
}

# Setup signal handlers
trap 'term_handler' SIGTERM

echo "Starting..."

echo "Set nmcli managed no"
nmcli dev set INTERFACE managed no

# Enforces required env variables
required_vars=(SSID WPA_PASSPHRASE CHANNEL ADDRESS NETMASK BROADCAST INTERFACE)
for required_var in "${required_vars[@]}"; do
    if [[ -z ${!required_var} ]]; then
        error=1
        echo >&2 "Error: $required_var env variable not set."
    fi
done

if [[ -n $error ]]; then
    exit 1
fi

#Setup interface
echo "iface $INTERFACE inet static"$'\n' >> /interfaces

# Setup hostapd.conf
echo "Setup hostapd ..."
echo "interface=$INTERFACE"$'\n' >> /hostapd.conf
echo "ssid=$SSID"$'\n' >> /hostapd.conf
echo "wpa_passphrase=$WPA_PASSPHRASE"$'\n' >> /hostapd.conf
echo "channel=$CHANNEL"$'\n' >> /hostapd.conf

if [ "$HIDEAP" = true ]; then
# Modify hostapd.conf to hide AP-ssid
	sed -i 's/ignore_broadcast_ssid=0/ignore_broadcast_ssid=1/g' hostapd.conf
fi

# Setup interface
echo "Setup interface ..."

#ip link set INTERFACE down
#ip addr flush dev INTERFACE
#ip addr add ${IP_ADDRESS}/24 dev INTERFACE
#ip link set INTERFACE up

echo "address $ADDRESS"$'\n' >> /etc/network/interfaces
echo "netmask $NETMASK"$'\n' >> /etc/network/interfaces
echo "broadcast $BROADCAST"$'\n' >> /etc/network/interfaces

ifdown INTERFACE
ifup INTERFACE

echo "Starting HostAP daemon ..."
hostapd -d /hostapd.conf & wait ${!}
