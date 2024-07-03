tags: [vpn, wireguard, privacy, linux, config, gist]
summary: |
  Setting up a wireguard network namespace for privateinternetaccess.com

Wireguard box for PIA
=====================

This article shows how to setup a WireGuard_ connection for PIA_ inside a
linux network namespace. This means that applications started in this
namespace never see other network interfaces even if the VPN is disrupted.

.. _WireGuard:          https://www.wireguard.com/
.. _PIA:                https://www.privateinternetaccess.com/

This is a follow-up on `VPN in a Nutshell`_ and `VPN autostart`_ which
describe how to do the same for the *OpenVPN* based connection. However,
openssl 3.3.0 rejects the current PIA certificate with ``X509_REVOKED``
causing the *OpenVPN* connection to fail — which has made it necessary for me
to migrate to WireGuard. More in this `GitHub discussion`_.

.. _GitHub discussion:  https://github.com/openssl/openssl/discussions/24301
.. _VPN in a Nutshell:  ../../../../2017/01/29/vpn-box
.. _VPN autostart:      ../../../../2017/02/24/vpn-autostart

Using WireGuard with network namespaces seems to be a standard approach that
is well-documented in various places, so I won't explain the steps here, and
just provide the setup and code. I recommend reading `Using WireGuard for
specific Apps on Linux`_ and `Routing & Network Namespace Integration`_ for
more details.

PIA has published code for setting up wireguard connections in their
manual-connections_ repository. If you're not interested in the custom setup
shown in this article here, I recommend you check it out.

.. _Using WireGuard for specific Apps on Linux:
   https://www.procustodibus.com/blog/2023/04/wireguard-netns-for-specific-apps/#enable-selectively
.. _Routing & Network Namespace Integration:
   https://www.wireguard.com/netns/
.. _manual-connections:
   https://github.com/pia-foss/manual-connections


Enough talk, more action!
-------------------------

pia-wirebox.conf
~~~~~~~~~~~~~~~~

You can determine an appropriate PIA host using get_region.sh_:

.. code-block:: bash

    git clone https://github.com/pia-foss/manual-connections.git
    sudo ./manual-connections/get_region.sh

Look for a line near the bottom of the output that reads:

.. code-block:: none

    Wireguard   IP ADDRESS      -   HOSTNAME

Now, create a file with your PIA credentials and server that you want to
connect to:

.. code-block:: ini
    :caption: /etc/wireguard/pia-wirebox.conf

    PIA_USER=p1234567
    PIA_PASS=your-password
    WG_HOSTNAME=frankfurt408
    WG_SERVER_IP=138.199.18.71

Prevent others from reading this file to protect your credentials:

.. code-block:: bash

    sudo chown root:root /etc/wireguard/pia-wirebox.conf
    sudo chmod 600       /etc/wireguard/pia-wirebox.conf


.. _get_region.sh:
   https://github.com/pia-foss/manual-connections/blob/master/get_region.sh


pia-wirebox
~~~~~~~~~~~

Download the pia-wirebox_ script, read it (!), adapt it to your needs if
necessary, and install it on your system, for example in
``/usr/local/bin/pia-wirebox``.

**Make sure** that it is only writable by root:

.. code-block:: bash

    sudo chown root:root /usr/local/bin/pia-wirebox
    sudo chmod 711       /usr/local/bin/pia-wirebox

.. _pia-wirebox: ./pia-wirebox


sudoers
~~~~~~~

I also like to setup passwordless sudo for my user. To do so start editing the
``sudoers`` file by running

.. code-block:: bash

    sudo visudo

*Note:* Using ``visudo`` is important to avoid accidentally locking yourself
out of your system due to a malformed sudoers!  Do not falter if you detest
vi(m).  Contrary to what it's name suggests, it can also be used with a
different editor by using e.g. ``sudo SUDO_EDITOR=nano visudo`` (but the
editor command needs to be *blocking*, i.e. stay in foreground until the file
is closed).

Add these lines near the bottom and replace *thomas* by your actual username:

.. code-block:: bash
    :caption: /etc/sudoers

    thomas ALL=(ALL:ALL) NOPASSWD: /usr/local/bin/pia-wirebox up
    thomas ALL=(ALL:ALL) NOPASSWD: /usr/local/bin/pia-wirebox down
    thomas ALL=(ALL:ALL) NOPASSWD: /usr/local/bin/pia-wirebox run thomas *

**Important:** Do not leave out the subcommand or the ``<USERNAME>`` part from
any of these lines! Without it, you will get passwordless sudo to run any
command as any user.

If you prefer, you can define these settings in their own file under
``/etc/sudoers.d`` using:

.. code-block:: bash

    sudo visudo /etc/sudoers.d/pia-wirebox

This requires a ``@includedir /etc/sudoers.d`` line in ``/etc/sudoers``.

An sleek alternative (that simplifies the installation process and avoids the
risk of misconfiguring your system) is to make use of the SUID bit. However,
for security reasons, linux does not allow this for interpretable scripts.
This would require creating a real binary (using e.g. ``shc``), but this is
outside the scope of this article.


Usage
~~~~~

With the above setup you should now be able to bring up the VPN and run a
command in the network namespace by hitting:

.. code-block:: bash

    sudo wirebox run $USER COMMAND [args..]

If desired, set up a script or an alias to make this easier for you, e.g.:

.. code-block:: bash
    :caption: ~/.bashrc

    alias wirebox="sudo pia-wirebox run $USER"


Related resources
-----------------

- `Using network namespaces to force VPN use on select applications`_
- wg-netns_

.. _Using network namespaces to force VPN use on select applications:
   https://try.popho.be/vpn-netns.html
.. _wg-netns:
   https://github.com/dadevel/wg-netns
