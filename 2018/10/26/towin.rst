public: yes
tags: [dual-boot, linux, config, grub, tricks, snippet]
summary: |
  Making use of grub-reboot

Reboot to windows
=================

A beginner treat from the tips and tricks box today:

For dual-booters like me, it is sometimes very convenient to boot from linux
directly into windows without having to watch the boot menu. If you're using
grub, this is possible with the the ``grub-reboot`` command. It can be called
with the name of the windows boot entry as follows:

.. code-block:: bash

    sudo grub-reboot 'Windows Boot Manager (on /dev/nvme0n1p1)'
    sudo reboot

The exact line will of course differ on most systems and can be read off from

.. code-block:: bash

    grep -i windows /boot/grub/gruf.cfg

Alternatively, ``grub-reboot`` can be called with the index of the boot entry,
but I prefer using the name for more clarity and stability.

(BTW: If you don't use grub but rely on an efi boot manager instead, there are
also tools to set efi variables for the next reboot, see e.g. ``efibootmgr
-n``.)

Wrapping it up
~~~~~~~~~~~~~~

For convenience, I recommend putting this in ``/usr/local/bin``:

.. code-block:: bash
    :caption: /usr/local/bin/towin

    grub-reboot 'Windows Boot Manager (on /dev/nvme0n1p1)' && reboot

To make it even more convenient, add the following alias in your ``.bashrc``:

.. code-block:: bash
    :caption: ~/.bashrc

    alias towin="sudo towin"

and enable passwordless execution for this script by typing ``sudo visudo``
and appending the following line:

.. code-block::  bash

    # put this near the end of the file(!)
    alice ALL=(ALL:ALL) NOPASSWD: /usr/local/bin/towin

Don't forget to ``chown root`` and ``chmod 755`` the ``towin`` script!


Wake on LAN
~~~~~~~~~~~

If you like this, you may also be interested in setting up your computer for
Wake on LAN, see `WOL dual-boot`_. I recommend configuring grub to boot linux
by default, also set a short wait time, and don't let it save your last
choice:

.. code-block:: ini
    :caption: /etc/default/grub

    GRUB_DEFAULT=0
    GRUB_TIMEOUT=1

    # Don't uncomment:
    # GRUB_SAVEDEFAULT="true"

Once linux is up you can always quickly ``towin`` back to windows if you've
missed the boot menu. Even remotely booting to windows can be achieved by
waking the PC to boot linux first and then executing ``towin`` via SSH.

Regenerate the ``grub.cfg`` with:

.. code-block:: bash

    sudo grub-mkconfig -o /boot/grub/grub.cfg

.. _WOL dual-boot: /2018/10/10/wol-dualboot


System independent script
~~~~~~~~~~~~~~~~~~~~~~~~~

If you want to maintain the same script across different machines, the
following may just work in many cases:

.. code-block:: bash

    windows_boot_entry="$(
        grep -i windows /boot/grub/grub.cfg |
        awk -F\' '{print $2}' )"

    grub-reboot "$windows_boot_entry"
