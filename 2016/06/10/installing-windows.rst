tags: [windows, rant, installation, config]
summary: |
  …is as easy as it gets (a.k.a. still a PITA)

Installing windows…
===================

I installed windows to my laptop the other day (yes, for gaming - you caught
me). I scheduled 2 hours to be done with all of it - what can go wrong, right?
It turns out, I am either lacking the necessary IT skills, or installing
windows is considerably more complicated than archlinux.

.. contents:: :local:
    :depth: 1


The boot medium
~~~~~~~~~~~~~~~

The trouble started with getting a bootable installation medium.  First, I
tried two Win7 DVDs I had left from previous installations. Neither one
worked: The first one didn't boot at all, the other one booted but then just
hung up in the loading screen. They are a couple of years old, so maybe they
turned bad. Since I didn't want to burn another DVD, I decided to try creating
a bootable USB pen drive. From the linux world, I am used to just doing ``dd
if=image.iso of=/dev/sdb`` to copy the image onto the stick, but no luck with
the windows image. Apparently, you are supposed to use special program to
create the bootable device from the image (WTF why?).

WUDT
----

First option, the official tool from Microsoft: `Windows USB/DVD Download
Tool`_, which (despite its name) creates bootable USB pen drive from previously
downloaded windows images. Okay, so I insert my zero'ed USB pen, and cancel
the *Format device* dialog presented by windows, confident that the tool will
take all necessary steps. However at ``Step 3 of 4: Insert USB device`` of the
wizard, after selecting the device I can't proceed. WUDT spits out::

    The selected USB device I:\(Removable Disk) is in use by another program.
    Please close all applications and try again.

.. _Windows USB/DVD Download Tool: https://www.microsoft.com/en-us/download/windows-usb-dvd-download-tool


Okay, I close the explorer, maybe it somehow is responsible for that. Still
the same message. I reinsert the device, this time applying the *Format*
dialog in the default setting (Quick format FAT). Indeed, now I can proceed.
The error message seems very off considering that the problem was that the
device was not formatted.

Whatever. I proceed with ``Step 4 of 4: Creating bootable USB device`` and it
tells me ``Status: Formatting...``. Yay! Formatting the device twice?
Whatever, yay! But then, only moments after the initial delight::

    We were unable to copy your files. Please check your USB device and the
    selected ISO file and try again.

The internet mentions, you need to `setup the partition` correctly before
anything else. I wonder, this tool has only one job, and it can't even format
the device for me? Sad, I start a ``cmd.exe`` as administrator and enter as
recommended:

.. _setup the partition: https://ardamis.com/2012/03/03/windows-7-usbdvd-download-tool-unable-to-copy-files/

.. code-block:: batch

    diskpart
    list disk
    select disk 2
    clean
    create partition primary
    select partition 1
    active
    format quick fs=fat32
    assign
    exit
    exit

This time the image gets burnt! Full of joy, I reboot my PC, select the USB
device to boot from and…

…nothing happens. Okay then.

Rufus to the rescue?
--------------------

Let's try rufus_, another tool to create bootable USB devices. It turns out
that this tool even takes care to create the partitions. Great, finally!

.. _rufus: https://rufus.akeo.ie/

Using the default setting ``MBR partition scheme for BIOS or UEFI-CSM``, the
image is copied successfully. No errors, no pain! I reboot and select the USB
device as boot medium…

…Nothing.

Okay, just out of curiosity, switch the boot manager from ``UEFI Only`` to
``UEFI/Legacy`` (with UEFI first). This time the USB device actually boots!
Wow, problem solved.  I still don't know why it was not UEFI bootable before,
since I explicitly selected that it should be (and there was an ``efi`` folder
on the device), but that at least explains why the first USB pen drive created
by WUDT might not have worked (DVDs still don't work). All that is in the past
now.

Or is it?  The installation ends rather quickly when I get to the step where
you have to select the installation partition. I did format my laptop with a
GPT partition scheme and windows complains::

    Windows cannot be installed to this disk. The selected disk is of the GPT
    partition style.

Apparently, windows refuses to install to GPT partitions because it was booted
in legacy mode. I have no clue why they don't just show a warning and let the
user proceed anyway if he so wishes. It makes no sense to me. Since most of my
hard drive is already in use with encrypted linux and data partitions, it's no
option to change to MBR partitioning scheme (which is the solution most
commonly suggested).

I will have to create a GPT UEFI-only boot device. Luckily, there is a
corresponding mode ``GPT partition scheme for UEFI`` in rufus. However, after
a short time rufus shows an error dialog::

    -> Error: ISO image extraction failure.


Finally
-------

Let's do one last attempt. One site mentions that the bootable USB device can
also be `created manually`_:

.. _created manually: http://www.eightforums.com/tutorials/15458-uefi-bootable-usb-flash-drive-create-windows.html

.. code-block:: batch

    diskpart
    select disk 2
    clean
    create partition primary
    format fs=fat32 quick
    active
    assign
    exit

Then simply copy the files in the ``.iso`` to the device. Alternatively, you
can directly extract the iso onto the device using 7z. Indeed, this time
everything works well! Windows is installed in half an hour or so. (By now,
I've decided to directly install Win10.)


Fix internet access
~~~~~~~~~~~~~~~~~~~

Now that I finally have windows up and running, let's download and install all
necessary drivers. Oh right: Win10 has only its own browser *Edge* (and IE)
shipped by default. Let's quickly download Firefox and be done with it. But
what is this? I can use google and go to the Mozilla website but when I try to
download Firefox, Edge tells me that it can't find the page. It figures that
Microsoft won't let me download another browser :D

No seriously, other parts of the internet don't work either. I can access
google and the Mozilla mainpage but not the downloads subdomain. No automatic
updates either. No github, no stackoverflow. Sad world.

Researching the problem on my other PC. There is talk that this may be due to
the *DNS Client* windows service not running or due to the network being set
to public.  Not in my case. Others mention it would be a bug in *Edge*, but
why then doesn't Windows Updates work neither?  And the problem persists in
Firefox that I have meanwhile downloaded using another computer and
transmitted via the good old USB pipeline:)

Finally, I notice that my LAN IP is not in the ``192.168.178.0/24`` subnet
that we use locally. Instead, I have an address in the ``169.254.0.0/16``
range. It turns out that this subnet belongs to the *Automatic Private IP
Addressing* (APIPA_) protocol, an IP self-configuration protocol that can be
used when DHCP fails. To disable this *feature*, edit the registry:

.. _APIPA: https://en.wikipedia.org/wiki/Link-local_address#IPv4

.. code-block:: registry

    Windows Registry Editor Version 5.00

    [HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\Tcpip\Parameters]
    "IPAutoconfigurationEnabled"=dword:00000000

This can be done by importing this regedit file: `DisableAPIPA.reg`_.

.. _DisableAPIPA.reg: ../DisableAPIPA.reg

Afterwards reboot. Internet works now! Great, but why did it use APIPA in the
first place if DHCP works so smoothly?  Why did part of the internet work? I
don't know.

I boot to my linux to check that all is still fine there. Confusingly, now my
internet on linux is broken! Again, I can load google, but not much else.
``ifconfig`` tells me that I don't have a IPv4 address. I got this same
behaviour on two separate machines after disabling APIPA on windows.  Why? I
don't know. I delete the machines from the list of known DHCP clients in the
fritzbox (router) web interface. Now it works again, on both linux and
windows.


Miscellaneous
~~~~~~~~~~~~~

After hours of delay, I can finally start installing drivers and fixing all
those small annoyances that windows delivers in its default configuration.
These aren't huge issues. They are just annoying and each one of them cost me
several minutes to navigate the corresponding config dialog by clicking
through settings pages. And some of them really make wonder why anyone would
consider them reasonable default settings. For example:

- There are about a dozen tiles in the start menu displaying stuff that I'm
  not interested in. This includes things like advertisement (!!), barby,
  minecraft and many others. These tiles can be disabled by right-clicking and
  unpinning every single one of them individually.

- There is a lock screen before you can login, requiring **one additional
  keypress**! So salty right now. This can be disabled by importing the
  DisableLockScreen.reg_ patch into the registry:

.. code-block:: registry

    Windows Registry Editor Version 5.00

    [HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Personalization]
    "NoLockScreen"=dword:00000001

- It's the 21st century, why do we still have CAPS LOCK? On linux I set it to
  *Escape* for more convenient *vim*-editing, but on windows I'm happy to
  remap it to *ScrollLock* to make it useful as a hotkey for PushToTalk or to
  enable/disable the microphone in mumble or teamspeak.
  SwitchCapsToScrollLock.reg_:

.. code-block:: registry

    Windows Registry Editor Version 5.00

    [HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layout]
    "Scancode Map"=hex:00,00,00,00,00,00,00,00,02,00,00,00,46,00,3a,00,00,00,00,00


- The most useful icon in the notification area for me is the one with which
  you can eject external USB devices. However, this is the only icon that is
  hidden by default. Instead, an upwards arrow is shown which you have to
  click first in order to access the icon. Let me make this clear: the most
  useful item requires one additional mouse click and since this is the only
  hidden icon by default, no space in the actual notification area is saved by
  this decision: it still requires the space for the upwards arrow. It took me
  at least 10 minutes to click to the corresponding config dialog with which
  you can choose to show all icons.

The following concerns bad default configuration of the UltraNav driver for my
thinkpad touch pad which significantly worsened the behaviour of the touchpad
right after installing the driver:

- By default, the mode for the middle mouse button is set to *Scrolling*
  rather than *Middle click*. This means that you can't properly use middle
  click anywhere. For example, in Firefox you can't open links in new tabs
  using middle click. You can't press the middle button once to enable scroll
  mode as usual. Instead you have to hold the middle button while scrolling
  and the scrolling works pretty awful. It feels useless.

- The two finger scroll direction is set to *inverted* by default. This means
  you have to move your fingers upwards to scroll down.


.. _DisableLockScreen.reg: ../DisableLockScreen.reg
.. _SwitchCapsToScrollLock.reg: ../SwitchCapsToScrollLock.reg

Conclusion
~~~~~~~~~~

Installing windows is fun! You should do it too!

More seriously: Don't use tools to create a bootable USB pen drive, just go
the manual route, that actually works.
