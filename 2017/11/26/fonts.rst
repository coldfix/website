public: yes
tags: [linux, config, fonts]
summary: |
  Just let me configure my font size!

Configure font
==============

How to attend to everyone's special needs…

X11
---

Installing is easy:

.. code-block:: bash

    sudo pacman -S adobe-source-code-pro-fonts      # monospace
    sudo pacman -S ttf-dejavu                       # and regular

but here is where it gets annoying…:


GTK2
~~~~

.. code-block:: ini
    :caption: ~/.gtkrc-2.0

    gtk-font-name = "DejaVu Sans 8"

And what about ``gtkrc-reload``?

GTK3
~~~~

(firefox, thunderbird, ??)

.. code-block:: ini
    :caption: ~/.config/gtk-3.0/settings.ini

    [Settings]
    gtk-font-name = DejaVu Sans 8

Qt4
~~~

(vlc)

.. code-block:: bash

    qtconfig-qt4

xterm
~~~~~

.. code-block:: properties
    :caption: ~/.Xresources

    XTerm*faceName: Source Code Pro
    XTerm*faceSize: 10

urxvt
~~~~~

.. code-block:: properties
    :caption: ~/.Xresources

    URxvt.font: xft:Source Code Pro:size=10

termite
~~~~~~~

.. code-block:: ini
    :caption: ~/.config/termite/config

    [options]
    font = Source Code Pro 10


terminator
~~~~~~~~~~

.. code-block:: ini

    [profiles]
      [[default]]
        background_image = None
        cursor_color = "#ffffff"
        font = Inconsolata Bold 10


console
-------

There is only one reasonable font here:

.. code-block:: bash

    yaourt -S terminus-font-ll2-td1
    sudo setfont ter-216n

For different sizes, try 212, 214, 216, 218, …

Make it permanent:

.. code-block:: ini
    :caption: /etc/vconsole.conf

    FONT=ter-216n
    FONT_MAP=8859-2_to_uni

and rebuild:

.. code-block:: bash

    sudo mkinitcpio -p linux

more?
-----

I'm sure there is plenty more. Please let me know about those that I didn't
find yet!
