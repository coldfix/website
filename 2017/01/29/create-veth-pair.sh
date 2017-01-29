#! /bin/sh

# network addresses for virtual ethernet adapter pair:
# (choose according to your liking)
virt_ip_host=10.200.1.1
virt_ip_peer=10.200.1.2
virt_network=10.200.1.0/24
virt_netmask=255.255.255.0

veth_tunnel_up() {
    # create network namespace
    ip netns add vpn || true
    ip -n vpn link set lo up

    # setup virtual ethernet adapters
    ip link add veth0 type veth peer name veth1
    ifconfig veth0 "$virt_ip_host" netmask "$virt_netmask" up

    # move one adapter to netns and bring it up there
    ip link set veth1 netns vpn up
    ip netns exec vpn ifconfig veth1 "$virt_ip_peer" netmask "$virt_netmask" up
}

veth_tunnel_down() {
    ip link del veth0
}
