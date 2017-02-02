public: yes
tags: [VPN, privacy, linux, config, gist]
summary: |
  Force certain applications to VPN while others stay on your default channel.

VPN in a Nutshell
=================

Ever wanted to tunnel only specific applications through your VPN?

.. contents:: :local:

Why you ask?
~~~~~~~~~~~~

Plenty of reason for that:

- Never accidentally leak traffic through the unencrypted connection, e.g.
  when your VPN dies.
- Traffic-intense applications like youtube or downloads can go over normal
  connection and are unaffected by the typically lower bandwidth limit on VPN.
- Can normally use applications that may be inaccessible through your VPN,
  e.g. email providers that block logins from the IP of the VPN.
- When your VPN goes online, unaffected applications don't need to reconnect
  using a different IP. This could e.g. cause your instant messanger to
  miss messages sent to the old IP.
- Not sharing the same IP for authenticated logins such as your
  email/youtube/IM with security-critical applications, potentially improving
  anonymity.


Recommended solution
~~~~~~~~~~~~~~~~~~~~

IMO, the best solution is to move the VPN network adapter to a linux `network
namespace`_. This ensures that only specific applications have access to the
VPN and these applications have only access to VPN. Proceed as follows:

.. _network namespace: https://lwn.net/Articles/580893/

Extend your OpenVPN config file by adding the following lines at the end of
the file:

.. code-block:: bash
    :caption: /etc/openvpn/CONNECTION.conf

    # Configure interface later:
    ifconfig-noexec

    # Don't route all traffic on this machine through VPN:
    route-noexec

    # Enable up-script
    script-security 2
    up   /etc/openvpn/move-to-netns.sh
    down /etc/openvpn/move-to-netns.sh


Download the following move-to-netns.sh_ script and make it executable:

.. _move-to-netns.sh: ../move-to-netns.sh

.. code-block:: bash
    :caption: /etc/openvpn/move-to-netns.sh

    #! /bin/bash

    up() {
        # create network namespace
        ip netns add vpn || true

        # bring up loop device
        ip netns exec vpn ip link set dev lo up

        # move VPN tunnel to netns
        ip link set dev "$1" up netns vpn mtu "$2"

        # configure tunnel in netns
        ip netns exec vpn ip addr add dev "$1" \
                "$4/${ifconfig_netmask:-30}" \
                ${ifconfig_broadcast:+broadcast "$ifconfig_broadcast"}
        if [ -n "$ifconfig_ipv6_local" ]; then
                ip netns exec vpn ip addr add dev "$1" \
                        "$ifconfig_ipv6_local"/112
        fi

        # set route in netns
        ip netns exec vpn ip route add default via "$route_vpn_gateway"
    }

    down() { true; }

    "$script_type" "$@"

    # update DNS servers in netns
    if [ -x /etc/openvpn/update-resolv-conf ]; then
        ip netns exec vpn /etc/openvpn/update-resolv-conf "$@"
    fi

Note this is a slightly modified version of Sebastian Thorarensen's
`netns-script`_. The main difference is that I prefer not to destroy the
namespace when VPN goes down. This will allow to restart VPN and attach it to
an already existing network namespace without having to restart tunneled
applications.

.. _netns-script: http://www.naju.se/articles/openvpn-netns.html

Now, when your VPN is online you can start applications with

.. code-block:: bash

    sudo ip netns exec vpn sudo -u $(whoami) -- COMMAND

You should check this now using a ``ping`` command.

Also observe (and verify!) that the ping fails to reach the destination once
you stop the VPN — and succeeds again once you restart.

Always trouble with DNS
~~~~~~~~~~~~~~~~~~~~~~~

You may find that you can access internet sites by IP address but not by
hostname (check using ``ping``). In this case you may also need the
`update-resolv-conf`_ script to update your DNS configuration for use with the
VPN. Save it to ``/etc/openvpn/update-resolv-conf`` and make it executable.

.. _update-resolv-conf: https://raw.githubusercontent.com/coldfix/openvpn-routing-examples/master/netns/move/update-resolv-conf

For your convenience
~~~~~~~~~~~~~~~~~~~~

vpnbox command
--------------

Once everything works, make your life easier by adding the following script:

.. code-block:: bash
    :caption: /usr/local/bin/vpnbox

    #! /bin/sh
    sudo ip netns exec vpn sudo -u "$(whoami)" -- "$@"

Now you can start applications using the simpler notation ``vpnbox COMMAND``.

You could simply add it as an alias, but I prefer it to be a real command so
non-shell applications and non-interactive shells can use it too. Of course,
it can be put anywhere in your ``$PATH``, personally I use ``~/bin/``.

If you're using zsh, add command completion for your shiny new ``vpnbox``
command as follows:

.. code-block:: bash
    :caption: ~/.zshrc

    compdef _precommand vpnbox

As a further convenience, you can modify the ``vpnbox`` command to start the
VPN (if not already running) before executing the user-requested command.

passwords are for nerds
-----------------------

If you want to enable password-less access to the VPN network namespace, fire
up ``sudo visudo`` and append a line such as the following

.. code-block:: bash
    :caption: /etc/sudoers

    # put this near the end of the file:
    alice ALL=(ALL:ALL) NOPASSWD: /usr/bin/ip netns exec vpn sudo -u alice -- *

Note the final ``--`` is important to prevent the user from passing other
options to ``sudo``.

firefox
-------

There is a minor complication when starting firefox: The command ``vpnbox
firefox --private-window`` **does not work** as expected! The boxed firefox
process will first look for existing instances and if one is open, tell it to
open the new window instead, leaving you with a new window that is not inside
the network namespace.

To prevent this from happening, you have to specify ``--no-remote``. However,
in this case, you cannot open the same user profile with both firefox
instances. Therefore, first setup a new profile called *vpn* using ``firefox
-p``. Now you can add an alias or command to start the profile in a tunneled
instance:

.. code-block:: bash
    :caption: /usr/local/bin/foxtunnel

    #! /bin/sh
    vpnbox firefox -P vpn --no-remote --private-window "${1-http://ipecho.net/plain}"

This will open up a new tunneled firefox displaying your external IP address.

Leaving VPN config files unmodified
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If you don't like to fiddle around with the VPN config files in expectation of
making them harder to maintain when your VPN provider releases updated
versions, you need not worry. The additional options can simply be given as
command line arguments to openvpn instead, e.g.:

.. code-block:: bash

    openvpn --ifconfig-noexec --route-noexec --script-security 2 \
            --up move-to-netns.sh --down move-to-netns.sh

Alternative approaches
~~~~~~~~~~~~~~~~~~~~~~

Moving the VPN adapter to a network namespace is the simplest and most
failsafe way for a lot of use cases. However, it cannot hurt to have a few
options at your disposal to learn from.

I know of three basic approaches to restrict certain applications to VPN:

.. contents:: :local:

The advantage of the network namespace is that it allows cleaner separation
without further firewall rules and can also prevent *normal* applications from
accessing the VPN tunnel.


Configure application to use VPN tunnel
---------------------------------------

*Some* applications allow to specify which network address they should bind
to. The IP address can be obtained using a command such as (you best put this
to your ``~/.bashrc``):

.. code-block:: bash

    ifip() { ifconfig "$1" | grep 'inet ' | sed -r 's/^.*inet +([0123456789.]+).*$/\1/'; }

Now, you can for example ``wget`` through the VPN by doing:

.. code-block:: bash

    wget --bind-address="$(ifip tun0)" http://ipecho.net/plain -O - -q

To make this work, you must also create a *routing table* (as root, once):

.. code-block:: bash

    echo "10 vpn" >> /etc/iproute2/rt_tables

and add to your VPN config:

.. code-block:: bash
    :caption: /etc/openvpn/CONNECTION.conf

    script-security 2
    route-noexec
    route-up /etc/openvpn/route-up-nopull.sh

and save the following route-up-nopull.sh_ script:

.. _route-up-nopull.sh: ../route-up-nopull.sh

.. code-block:: bash
    :caption: /etc/openvpn/route-up-nopull.sh

    #! /bin/sh
    ip route add default via "$route_vpn_gateway" dev "$dev" table vpn
    ip rule add from "$ifconfig_local"/32 table vpn
    ip rule add to "$route_vpn_gateway"/32 table vpn
    ip route flush cache

How this works:

- the ``ip rule add`` commands define rules that say all communication with
  the IP address of the VPN tunnel should be routed using the routing table
  called *vpn*.
- the table *vpn* defines only one route: through the VPN tunnel device

**WARNING:**

- DNS requests may still be going over your unencrypted connection

Implications:

- the VPN interface is visible to all applications, but they will not use it
  as long as you do not add a route through the tunnel.
- sensitive applications see all network interfaces, but they will not use
  them if they are programmed properly and the routing table contains no other
  routes.
- in principal all applications *can* use both network interfaces

Reference:

    https://snikt.net/blog/2013/10/10/how-to-force-program-to-use-vpn-tunnel/


Start applications with dedicated user/group
--------------------------------------------

A_ commonly_ suggested_ possibility_ is to create a special user or group and
create firewall rules that will route all traffic of the user using a
dedicated routing table.

**WARNING:** I deem this method unsafe and advise against using it. For more
details, see the end of the section.

.. _A: http://askubuntu.com/questions/37412/how-can-i-ensure-transmission-traffic-uses-a-vpn
.. _commonly: https://forums.linuxmint.com/viewtopic.php?t=175765
.. _suggested: http://serverfault.com/questions/95813/only-tunnel-certain-applications-via-openvpn
.. _possibility: http://blog.sebastien.raveau.name/2009/04/per-process-routing.html

This solution also requires a routing table (if you haven't created it
already for the previous approach):

.. code-block:: bash

    echo "10 vpn" >> /etc/iproute2/rt_tables

Also, create a linux group *vpn* (don't confuse the group with the table,
their names can be chosen independently, but I happen to like *vpn* in both
cases):

.. code-block:: bash

    groupadd vpn

Creating a dedicated *user* is the more commonly described variant of this
approach, but I prefer using a *group*. It seems more modular to me in the
sense that it allows to start VPN constrained applications as any particular
user, i.e. without having to worry about filesystem access, etc...

Now add to your OpenVPN config file:

.. code-block:: bash
    :caption: /etc/openvpn/CONNECTION.conf

    script-security 2
    route-noexec
    up       /etc/openvpn/setup-for-group.sh
    route-up /etc/openvpn/setup-for-group.sh
    down     /etc/openvpn/setup-for-group.sh

And place the setup-for-group.sh_ script in your openvpn folder:

.. _setup-for-group.sh: ../setup-for-group.sh

.. code-block:: bash
    :caption: /etc/openvpn/setup-for-group.sh

    #! /bin/bash

    # NOTE: If you have iptable rules, do NOT blindly do any of the following.
    # You must take care manually that the rule sets do not interfere.

    up() {
        # Enable forwarding, see:
        # https://www.kernel.org/doc/Documentation/networking/ip-sysctl.txt
        echo 1 > /proc/sys/net/ipv4/ip_forward
        for f in /proc/sys/net/ipv4/conf/*/rp_filter; do
            echo 2 > $f
        done;

        # Avoid duplicate rules and emphasize that we are probably not compatible
        # with other iptable rules:
        false && delete_rules
        # Just kidding, we are not actually doing this. This would temporarily
        # disable rules for already running programs.

        # Mark packets coming from the vpn group
        iptables -t mangle -A OUTPUT -m owner --gid-owner vpn -j MARK --set-mark 42

        # Apply the VPN IP address on outgoing packages
        iptables -t nat -A POSTROUTING -o "$dev" -m mark --mark 42 -j MASQUERADE

        # Route marked packets via VPN table
        ip rule add fwmark 42 table vpn

        #----------------------------------------
        # security measures against leaking traffic on other interfaces:
        #----------------------------------------

        # If the routing table contains no routes, the next matching table can be
        # used - which can result in packages being routed over other interfaces.
        # To prevent this from happening, add a dummy entry that will keep the
        # table alive before its default route is setup and after it goes down:
        ip route add unreachable 0.0.0.0/32 table vpn

        # safeguard measure in case the above is insufficient: establish iptables
        # rules that will prevent traffic going on other interfaces:
        iptables -t mangle -A POSTROUTING -m mark --mark 42 -o lo     -j RETURN
        iptables -t mangle -A POSTROUTING -m mark --mark 42 -o "$dev" -j RETURN
        iptables -t mangle -A POSTROUTING -m mark --mark 42           -j DROP
    }

    route-up() {
        ip route add default via "$route_vpn_gateway" dev "$dev" table vpn
    }

    down() {
        # NOTE: do not delete the ip/iptables rules to decrease the likelihood of
        # data leaks
        true;
    }

    # This is how you can clear the rules, if you want to. This will not be
    # executed automatically.
    delete_rules() {
        iptables -t mangle -F OUTPUT
        iptables -t mangle -F POSTROUTING
        iptables -t nat    -F POSTROUTING
        ip rule del fwmark 42 table vpn
        ip route del 0.0.0.0 table vpn
        ip route del default table vpn
    }

    "$script_type" "$@"

    # update DNS servers
    if [ -x /etc/openvpn/update-resolv-conf ]; then
        /etc/openvpn/update-resolv-conf "$@"
    fi

Note that there is no conflict in sharing the same *vpn* routing table with
the one needed for the solution in the previous section.

The command prefix to start tunneled applications is now ``sudo -g vpn --``,
e.g.:

.. code-block:: bash

    sudo -g vpn -- wget http://ipecho.net/plain -O - -q

Nice, this was easier than expected. But do I really have to enter my
password? If you prefer not to, fire up ``sudo visudo`` and append a line as
the following

.. code-block:: bash
    :caption: /etc/sudoers

    # put this near the end of the file:
    alice ALL=(alice:vpn) NOPASSWD: ALL

This allows the user *alice* to start applications with group *vpn* without
having to enter her password.

**WARNING:** This method can leak traffic if for some reason the routing
table/iptable rules are ineffective, e.g.:

- some unforseen edge-case is not covered
- one or more of the rules is deleted (playing with your firewall?)
- other rules interfere
- before the rules are created

To emphasize: Before the rules are in effect there is no protection at all.
The implementation given here sets up the rules after starting the VPN rather
than at system boot, which means that programs will happily communicate over
the default interface until the VPN is first started.

In fact, it would be much better to setup all static rules (i.e. everything
done in the ``up()`` function except for the MASQUERADE rule) at system boot
time rather than when the VPN starts.

Virtual ethernet tunnel to network namespace
--------------------------------------------

I have already shown how to enforce VPN inside a network namespace by moving
the adapter to the namespace (`Recommended solution`_). While this is most
likely the best choice in most cases, there is a set of variants of this
strategy which I find more delightful from a learning perspective about linux
network technology, and which I will list just for the fun of it.

The basic idea is to first create a **virtual ethernet adapter pair** and then
move one of the adapters into the netns. We will put this functionality into a
`/etc/openvpn/create-veth-pair.sh`_ script.

.. _/etc/openvpn/create-veth-pair.sh: ../create-veth-pair.sh

From here there are several slightly different ways to get VPN within the
netns:

1. Start VPN normally; leave it outside the netns but connect it to the VPN
   adapter tunneling into the netns
2. Start VPN normally; then move it into netns; then connect the VPN adapter
   to the virtual ethernet peer in the netns
3. Bridge the outer virtual ethernet adapter to your ethernet/wifi and then
   start VPN directly inside the netns

In every case, applications can now be started with the `vpnbox command`_.
However, unlike for the `Recommended solution`_, these methods do also
establish principal a connection for all applications to both the plain
network and the VPN — which means that it is possible to simultaneously
support the two alternative methods (`Configure application to use VPN
tunnel`_, `Start applications with dedicated user/group`_) described in the
previous sections.

Be aware that these options offer little benefit compared with the recommended
solution, and they are far worse in terms of complexity. I believe it is easy
to miss some edge-case when designing the firewall rules required to make
these variants work, resulting in the possibility to leak traffic in some way
or the other. Personally, I wouldn't trust myself doing it *correctly* given
my limited knowledge in this subject.

In particular, the third variant will not protect you against leaking traffic
when the VPN goes down, if you don't take special care.

I will not discuss implementations for these methods in further detail. You
can get an idea how to achieve this from the methods presented above as well
as the following resources:

- `Bridging an ethernet with a virtual ethernet adapter <http://www.evolware.org/?p=293>`_
- `Nice illustration of virtual ethernet adapter pairs <https://blog.famzah.net/2014/06/05/private-networking-per-process-in-linux/>`_
- You should also get a fair knowledge about iptables.
