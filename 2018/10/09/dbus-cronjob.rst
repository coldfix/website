tags: [dbus, cron, linux, pidgin, util]
summary: |
  Using the correct D-Bus session ID within cronjobs or SSH.

D-Bus cronjobs
==============

D-Bus_ is inter-process communication framework that allows accessing and
controlling many applications such as NetworkManager, notify, pidgin, udisks,
and many more. The reason to be interested in this as a user, is that some
services may expose via their D-Bus API useful functionality and information
that is not available via a command line interface.

.. _D-Bus: https://www.freedesktop.org/wiki/Software/dbus/

However, if you try running a command that needs to communicate via the users
session bus from a cronjob or SSH session, you may find that this won't work
as expected without an extra bit of setup. This usually concerns user
applications that are started within the desktop session, such as pidgin. The
reason is that the environment is not initialized with the address of the
desired session bus, and the session bus may not even be unique if multiple
sessions are running for the same user.

.. contents:: :local:
    :depth: 1

The session bus address
~~~~~~~~~~~~~~~~~~~~~~~

Long story short, in order to run a cronjob that should interact with a
program that is running within the user's desktop session, it is your
responsibility to first set the ``DBUS_SESSION_BUS_ADDRESS`` environment
variable. In many cases, this will simply be:

.. code-block:: bash

    export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus

However, the session bus may not be unique or the program may be running on a
different session bus. For this reason, it is better to ask with which session
bus the program is running. For this, you need to acquire its process ID
first, e.g.:

.. code-block:: bash

    program=pidgin
    PID=$(pgrep $program)
    export DBUS_SESSION_BUS_ADDRESS=$(
        grep -z DBUS_SESSION_BUS_ADDRESS /proc/$PID/environ | cut -d= -f2-)

In other cases, you may want to talk to a program on a specific display number
(this is not working at the moment on my system, but maybe it does the job for
you):

.. code-block:: bash

    display=0
    machine=$(cat /var/lib/dbus-machine-id)
    session=~/.dbus/session-bus/${machine}-${display}
    source $session
    export DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID


Turning it into a command
~~~~~~~~~~~~~~~~~~~~~~~~~

I recommend to encapsulate the above solutions as pre-commands that can be put
in your PATH, e.g. ``/usr/local/bin`` or ``~/.local/bin``.

Guess session bus from currently logged in user id:

.. code-block:: bash
    :caption: bin/talk_to_myself

    #! /usr/bin/env bash
    export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
    "$@"

Determine session bus by program name:

.. code-block:: bash
    :caption: bin/talk_to_program

    #! /usr/bin/env bash
    program="$1"
    PID=$(pgrep "$program")
    export DBUS_SESSION_BUS_ADDRESS=$(
        grep -z DBUS_SESSION_BUS_ADDRESS /proc/$PID/environ | cut -d= -f2-)
    "${@:2}"

Determine session bus by display number:

.. code-block:: bash
    :caption: bin/talk_to_display

    #! /usr/bin/env bash
    display="$1"
    machine=$(cat /var/lib/dbus-machine-id)
    session=~/.dbus/session-bus/${machine}-${display}
    source $session
    export DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID
    "${@:2}"

Usage example
~~~~~~~~~~~~~

I have a purple-status_ python script that can be used to control the pidgin
online status. It can be used manually from the command line, or e.g.  within
a cronjob to go offline at a specified time. Type ``crontab -e`` and enter:

.. code-block:: none

    45 5 * * * ~/bin/talk_to_program pidgin ~/bin/purple-status off

Note that the script depends on ``python-gobject``.

.. _purple-status: ../purple-status

Others
~~~~~~

Meanwhile, to shutdown_ your PC you need the system bus and therefore no of
the above magic:

.. code-block:: none

    dbus-send --system --print-reply --dest=org.freedesktop.login1 \
        /org/freedesktop/login1 "org.freedesktop.login1.Manager.PowerOff" boolean:true

.. _shutdown: https://askubuntu.com/questions/454039/what-command-is-executed-when-shutdown-from-the-graphical-menu-in-14-04
