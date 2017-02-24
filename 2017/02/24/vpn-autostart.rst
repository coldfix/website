public: yes
tags: [VPN, privacy, linux, config, gist, utility]
summary: |
  Automatically start VPN before the using application.

VPN autostart
=============

In `VPN in a Nutshell <../../../01/29/vpn-box/>`_ I have described a command
prefix ``vpnbox``. This precommand executes applications in a network
namespace but does not take care to check if VPN is already up and
automatically start if it is not.

Unfortunately, I know no good (simple) way to do this. Please tell me if
you've got any better solutions.

First, modify the ``vpnbox`` command as follows:

.. code-block:: bash
    :caption: /usr/local/bin/vpnbox

    #! /usr/bin/bash

    # check if there is a default route in the netns going over tun0:
    # NOTE: 'tun0' may not be the correct interface name
    vpn_online() {
        sudo ip netns exec vpn sudo -u thomas -- ip route \
            | grep default | grep tun0
    }

    if ! vpn_online; then
        # Execute openvpn in daemon mode:
        sudo /bin/openvpn --config /etc/vpn/CONFIG.conf --daemon

        # Wait for completion. Otherwise routes/DNS information may not be
        # setup when the main program starts:
        echo "Waiting for route."
        while ! vpn_online; do
            sleep 0.1
        done
    fi

    # Execute the actual command as before:
    sudo ip netns exec vpn sudo -u thomas -- "$@"

To make this work without passwords, type ``sudo visudo`` to add the following
to your ``sudoers``:

.. code-block:: bash
    :caption: /etc/sudoers

    # put this near the end of the file:
    # this line is unchanged from the previous post:
    alice ALL=(ALL:ALL) NOPASSWD: /usr/bin/ip netns exec vpn sudo -u alice -- *

    # The following line is new and allows to start the vpn without password:
    alice ALL=(ALL:ALL) NOPASSWD: /usr/bin/openvpn --config /etc/openvpn/CONFIG.conf --daemon

**WARNING:** You must specify the exact line here. You must not use the ``*``
as a lazy shortcut here, otherwise a user can specify as additional parameters
any script and it will be executed as root.


Advanced version
----------------

Personally, I'm using another (more complex) solution that does not provide
much benefit over the simpler one given above. But since I've gone through the
development effort and learnt something from it and also it's slightly nicer,
I cannot let go yet.

The difference is that it does print some output of the ``openvpn`` command to
standard output and can exit early if an error occurs during the
initialization phase.

This is accomplished by exchanging the plain ``sudo openvpn`` statement in the
``vpnbox`` script above by the crazier command:

.. code-block:: bash

    sudo openvpn-daemonize /etc/openvpn/CONFIG.conf || exit 1

Huh? This wasn't so bad, was it?

Yeah, but you will also have to provide the ``openvpn-daemonize`` script. This
time I highly recommend to put it actually in ``/usr/local/bin`` and not in a
user path. Make it writable by root only (because we are executing it with
sudo).

.. code-block:: bash
    :caption: /usr/local/bin

    #! /bin/zsh

    cd /etc/openvpn
    config=$1

    basename=$(basename ${config%.*})
    log=/var/log/vpn/$basename.log
    writepid=/var/log/vpn/$basename.pid

    # Truncate log file to make sure it doesn't contain remnants
    echo >$log

    # Start VPN in background, this does not block
    /bin/openvpn --config $config --log $log --writepid $writepid --daemon

    # Create a temporary pipe that will be used to connect the standard IO of
    # the next two processes
    pipe=$(mktemp -u)
    mkfifo $pipe

    # Search for markers in the fifo stream, quit with exit code when found
    sed -e '/Initialization Sequence Completed/q0' \
        -e '/Connection refused/q1' <$pipe & sed_PID=$!

    # Follow the log, write output to pipe, but also exit when 'sed' exits
    tail -n +0 -f $log  --pid $sed_PID >> $pipe
    exitcode=$?

    # Cleanup and exit
    rm $pipe
    exit $exitcode

Also, convenience demands to add the following additional line in ``sudoers``:

.. code-block:: bash

    alice ALL=(ALL:ALL) NOPASSWD: /usr/local/bin/openvpn-daemonize /etc/openvpn/CONFIG.conf
