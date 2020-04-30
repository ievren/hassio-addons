#!/bin/bash

CONFIG_PATH=/data/options.json

SSID=$(jq --raw-output ".ssid" $CONFIG_PATH)
WPA_PASSPHRASE=$(jq --raw-output ".wpa_passphrase" $CONFIG_PATH)
CHANNEL=$(jq --raw-output ".channel" $CONFIG_PATH)
ADDRESS=$(jq --raw-output ".address" $CONFIG_PATH)
NETMASK=$(jq --raw-output ".netmask" $CONFIG_PATH)
BROADCAST=$(jq --raw-output ".broadcast" $CONFIG_PATH)
HIDEAP=$(jq --raw-output ".hide_ap" $CONFIG_PATH)
DEVICE=$(jq --raw-output ".device" $CONFIG_PATH)

# SIGTERM-handler this funciton will be executed when the container receives the SIGTERM signal (when stopping)
term_handler(){
	echo "Stopping..."
	ifdown DEVICE
	ip link set DEVICE down
	ip addr flush dev DEVICE
	exit 0
}

# Setup signal handlers
trap 'term_handler' SIGTERM

echo "Starting..."

echo "Set nmcli managed no"
nmcli dev set DEVICE managed no

# Enforces required env variables
required_vars=(SSID WPA_PASSPHRASE CHANNEL ADDRESS NETMASK BROADCAST)
for required_var in "${required_vars[@]}"; do
    if [[ -z ${!required_var} ]]; then
        error=1
        echo >&2 "Error: $required_var env variable not set."
    fi
done

if [[ -n $error ]]; then
    exit 1
fi

# Setup hostapd.conf
echo "Setup hostapd ..."
echo "ssid=$SSID"$'\n' >> /hostapd.conf
echo "wpa_passphrase=$WPA_PASSPHRASE"$'\n' >> /hostapd.conf
echo "channel=$CHANNEL"$'\n' >> /hostapd.conf

if [ "$HIDEAP" = true ]; then
# Modify hostapd.conf to hide AP-ssid
	sed -i 's/ignore_broadcast_ssid=0/ignore_broadcast_ssid=1/g' hostapd.conf
fi

# Setup interface
echo "Setup interface ..."

#ip link set DEVICE down
#ip addr flush dev DEVICE
#ip addr add ${IP_ADDRESS}/24 dev DEVICE
#ip link set DEVICE up

echo "address $ADDRESS"$'\n' >> /etc/network/interfaces
echo "netmask $NETMASK"$'\n' >> /etc/network/interfaces
echo "broadcast $BROADCAST"$'\n' >> /etc/network/interfaces

ifdown DEVICE
ifup DEVICE

echo "Starting HostAP daemon ..."
hostapd -d /hostapd.conf & wait ${!}
