#! /bin/bash

up() {
    echo 1 > /proc/sys/net/ipv4/ip_forward
    for f in /proc/sys/net/ipv4/conf/*/rp_filter; do
        echo 0 > $f
    done;

    # Mark packets coming from the vpn group
    iptables -t mangle -A OUTPUT -m owner --gid-owner vpn -j MARK --set-mark 42

    ## Apply the VPN IP address on outgoing packages
    iptables -t nat -A POSTROUTING -o "$dev" -m mark --mark 42 -j MASQUERADE

    # Route marked packets via VPN table
    ip rule add fwmark 42 table vpn
}

route-up() {
    ip route add default via "$route_vpn_gateway" dev "$dev" table vpn
}

down() {
    iptables -t mangle -F
    iptables -t nat -F
    ip rule del fwmark 42 table vpn
    ip route del default table vpn
}

"$script_type" "$@"

# update DNS servers
if [ -x /etc/openvpn/update-resolv-conf ]; then
    /etc/openvpn/update-resolv-conf "$@"
fi
