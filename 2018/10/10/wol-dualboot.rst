public: yes
tags: [wol, dual-boot, linux, windows, config]
summary: |
  Setting up Windows 10 and Linux for Wake-on-LAN

WOL dual-boot
=============

Setting up Wake-on-LAN for your PC may require configuring both your BIOS/UEFI as
well as your operating system. If multi-booting more than one OS, it's necessary
to set all of them up, since only the last running OS before shutdown determines
whether the PC will be listening for magic packets.

I will give a short and comprehensive write-up of all the steps it took for me
to make Wake-on-LAN work on a dual-boot system with archlinux and windows 10.
While there are already many guides, it is sometimes hard to find all the
relevant information in one place.

.. contents:: :local:
    :depth: 1

Linux
~~~~~

On linux, the ``ethtool`` program can be used as follows to enable WOL on your
network interface *for the next shutdown only*:

.. code-block:: bash

    ethtool -s INTERFACE wol g

where ``INTERFACE`` is the name of your ethernet adapter as displayed by ``ip
l`` or found via  ``ls /sys/class/net | grep en``, e.g. ``enp0s25``.

However, this setting will be lost after the next reboot! To make it
persistent it must be executed again on every reboot. This can be achieved
using cronjob, udev rules, systemd units or third-party packages.

Quite unsurprisingly, the archwiki has a great Wake-on-LAN_ article that
explains several alternatives to enable WOL. I will mirror some of the
information here, in case the wiki is modified:

.. contents:: :local:
    :depth: 1

cronjob
```````

Use the following cronjob to enable WOL on every reboot:

.. code-block:: bash

    @reboot /usr/bin/ethtool -s INTERFACE wol g

wol-systemd
```````````

The wol-systemd_ AUR package provides a simple systemd unit for running
``ethtool``. Install the package, then enable and start the unit:

.. code-block:: bash

    yaourt -S wol-systemd
    systemctl enable wol@INTERFACE
    systemctl start wol@INTERFACE

.. _Wake-on-LAN: https://wiki.archlinux.org/index.php/Wake-on-LAN
.. _wol-systemd: https://aur.archlinux.org/packages/wol-systemd/

NetworkManager
``````````````

If you're using NetworkManager, you can use enable WOL via ``nmcli``. First,
determine the name of your ethernet connection by typing:

.. code-block:: bash

    nmcli con show

then enable magic packets as follows:

.. code-block:: bash

    nmcli con modify "NAME" 802-3-ethernet.wake-on-lan magic

Windows
~~~~~~~

On windows, I ended up consulting several_ guides_ and modifying multiple
settings before WOL started working. Summary of steps:

Right click the windows icon and open the **Device Manager**. Navigate to
``Network Adapters`` and double-click your ethernet adapter. Then go to the
following tabs:

    - **Power Management**:
        - ``[x] Allow this device to wake the computer``
        - ``[x] Only allow a magic packet to wake the computer`` (to prevent
          waking up from other events)

    - **Driver**: *Update Driver* and let windows *Search automatically for
      updated driver software*. Afterwards reboot. This step may not be
      needed.

    - **Advanced**: Search the list for an ``Wake on Magic Packet`` entry and
      set it to enabled. If no such entry exists, update the driver and
      restart first.

Furthermore, you may have to disable the **fast startup** option in windows
(don't worry it will probably not noticably impact startup times):

    - Press ``Win + X`` and open ``Power Options``
    - Click ``Additional power settings`` on the right (under *related settings*)
    - Click ``Choose what the power buttons do`` on the left menu
    - Click ``Change settings that are currently unavailable``
    - Scroll to ``Shutdown settings``
    - Uncheck ``Turn on fast startup (recommended)``

Of course, they're changing the names and location of these settings on
seemingly every update, so good luck to you and future me;)

.. _several: https://www.makeuseof.com/tag/wake-on-lan-windows/
.. _guides: https://www.groovypost.com/howto/enable-wake-on-lan-windows-10/

UEFI
~~~~

Besides OS settings, it is usually necessary to enable WOL in UEFI as well.
The following settings are those that were necessary for me to touch to make
WOL finally work. Naturally, these options may be named differently, reside in
different sections, or may not even exist in your UEFI.

- Enable ``Boot -> Boot From Onboard LAN``
- Disable ``Boot -> Fast Boot``
- Enable ``Advanced -> ACPI Configuration -> PCIE Devices Power On``


Check packet reception
~~~~~~~~~~~~~~~~~~~~~~

If WOL just doesn't want to start working, you can check whether the
the target machine receives the magic packet with gnu-netcat:

.. code-block:: bash

    nc --udp --listen --local-port=40000 --hexdump

In this case, also make sure use the same port while sending the packet (``wol
-p PORT`` option). If you choose a protected port such as 9 you will need root
permissions for the netcat command above.

Alternatively, with ``wireshark`` once you've been added to the ``wireshark``
group (and logged out and in again), you can listen in as a user on all WOL
packets arriving on arbitrary ports:

.. code-block:: bash

    tshark -i INTERFACE -Y wol
