public: yes
tags: [linux, configuration, terminal, theme]
summary: |
  Why and how to use xterm or urxvt as your default terminal and customize
  their font and color scheme to look pleasing.

Oh my terminal!
===============

When you're ditching your fully blown desktop environment for a stand-alone
window manager like awesome_ you will have to make a lot of choices regarding
applications for basic daily tasks. Think of your instant messenger, email
client, web browser, text editor and even your terminal emulator. In fact,
being able (*and forced to!*) freely assemble your system might be the reason
to switch in the first place.


Which to use?
~~~~~~~~~~~~~

My requirements for a terminal are not all too fancy. All I want is a simple
application that *just works* and doesn't *get in the way*. I tried out
several of the `available terminal emulators`_ including rxvt_, urxvt_, the
ubiquitous xterm_ and others before I ended up using terminator_ for the last
couple of years. The other alternatives I discarded because most are lacking
multiple of the following treats in their default configuration:

- good looks
- 256 colors
- mouse support
- scrolling with mouse wheel seems to be an issue, in particular when done
  with pagers (``less``, ``man``, ``git help``)
- UTF-8 support
- hidden menu bar and scroll bar
- working Ctrl-/Shift + Arrow/F1-F12 key combinations in VIM

However, I now decided to give *rxvt-unicode* (also called *urxvt*) another go
and at the same time improve my *xterm* configuration as well for a couple of
reasons:

First, I hardly need nor use any of *terminator*'s impressive list of
features. I don't need split terminal windows when I have a tiling window
manager that can do basically the same thing in a more universal fashion. I
was always slightly unhappy with the feature-fuss and wanted to use a simpler
terminal.

Second, I occasionally get presented with an *xterm* window. This typically
happens when some application changes the way they figure out which terminal
to launch and suddenly my existing configuration is not enough to indicate
that *terminator* should be used. So they use *xterm* as a fallback. Having to
look at this ugly (default themed) terminal window every now and then created
at least some drag to enhance my configuration.

Third, ranger_, the file manager I currently use, has recently added support
for `True Color Image previews`_. This feature is currently available within
*xterm* and *urxvt* but not with *terminator*.

This created enough incentive for me to search for fixes to the above issues
and, indeed, for *urxvt* all of them can be solved. In the following, I will
first briefly describe how to configure *urxvt* to make it look better, to
address functional issues and finally how to set the default terminal for
non-desktop-environment systems.


Theming xterm and urxvt
~~~~~~~~~~~~~~~~~~~~~~~

As is true for many linux topics, the archwiki has wonderful articles `on
xterm`_ and `on urxvt`_ explaining most of what you will want to know. This is
a short summary on what I'm using here:

*xterm* and *urxvt* can be configured with Xresources_. The settings are
defined in a file named ``~/.Xresources`` and must be (re-)loaded using the
command ``xrdb -merge ~/.Xresources``. If starting your window manager via the
``startx`` command add the following lines to your ``~/.xinitrc`` near the top
(before ``exec``-ing the window manager itself):

.. code-block:: bash
    :caption: ~/.xinitrc

    [ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"

I prefer **Source Code Pro** over the default fonts used by *xterm* and
*urxvt*. Note that this font must be installed separately in archlinux:

.. code-block:: bash

    pacman -S adobe-source-code-pro-fonts

You can now configure your shiny new font to be used by adding the following
lines to the file:

.. code-block:: Xresources
    :caption: ~/.Xresources

    XTerm*faceName: Source Code Pro
    XTerm*faceSize: 13

    URxvt.font: xft:Source Code Pro:size=13

To change the color palette in both *xterm* and *urxvt* add the following
lines handling both terminals at once:

.. code-block:: Xresources
    :caption: ~/.Xresources

    ! Colors for XTerm+URxvt and maybe other terminals:
    *background: #002010
    *foreground: #a08080
    *cursorColor: #aaaaaa
    ! This colormap is copied from terminators builtin *Ambience* scheme
    ! (see /usr/lib/python2.7/site-packages/terminatorlib/prefseditor.py):
    *color0: #2e3436
    *color1: #cc0000
    *color2: #4e9a06
    *color3: #c4a000
    *color4: #3465a4
    *color5: #75507b
    *color6: #06989a
    *color7: #d3d7cf
    *color8: #555753
    *color9: #ef2929
    *color10: #8ae234
    *color11: #fce94f
    *color12: #729fcf
    *color13: #ad7fa8
    *color14: #34e2e2
    *color15: #eeeeec


Fixing scroll problem
~~~~~~~~~~~~~~~~~~~~~

On archlinux, there is a `AUR package`_ that you can install instead of the
plain *urxvt* package, which fixes the pager scrolling issue :

.. code-block:: bash

    yaourt -S rxvt-unicode-better-wheel-scrolling

Then add the following configuration to your ``~/.Xresources``:

.. code-block:: Xresources
    :caption: ~/.Xresources

    URxvt.secondaryScreen: 1
    URxvt.secondaryScroll: 0
    URxvt.secondaryWheel: 1

This information is taken from the archwiki article's section on `Scrollback
buffer in secondary screen`_.


Fixing key combinations
~~~~~~~~~~~~~~~~~~~~~~~

At this point, the last major remaining issue is that key combinations with
Control/Shift and Arrow keys as well as function keys don't work properly with
VIM. To my relief, I found a great blog entry `Uvxrt - Vim Arrow- and End-key
Problem`_ that lists a comprehensive list of keysym substitutions that will
fix the problem if added to your ``~/.Xresources`` file.


Setting the default terminal
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Unfortunately, there is not a single standard location to define the default
terminal to be used across your system. Rather, the configuration for almost
every tool that launches terminals or terminal-based applications must be
updated independently. You should at least update the following settings if
you have the corresponding programs installed.

First, you obviously have to set the correct terminal for the launchers of
terminal-based applications in

- menus
- quick launch icons
- hotkeys

If you use **awesome** as your window manager too, you likely have to
configure your ``~/.config/awesome/rc.lua`` to accomplish this. It's probably
wise to use the same launch function for all these use-cases, so you don't
need to update more than one or two lines when switching the terminal.

For **ranger** and **mimeopen** put the following lines somewhere near the top
of your ``~/.zprofile`` if your shell is *zsh* or in ``~/.bash_profile`` if
you use *bash*:

.. code-block:: bash
    :caption: ~/.zprofile

    # Used by ranger. Note that ranger doesn't handle absolute pathes.
    export TERMCMD="urxvt"

    # Used by mimeopen when launching applications with Terminal=true:
    export TERMINAL="urxvt -e"
    # export TERMINAL="terminator -x"   # for  terminator

**xdg-open** as of version 1.1.1 never launches a new terminal on its own, so
there is currently no separate configuration for this tool. On the other hand
this means that you had to specify the terminal command in every ``.desktop``
file describing a terminal-based application. Therefore, you may need to
update several desktop files in ``~/.local/share/applications``.

Note that *xdg-open* and *mimeopen* use different files to infer the default
applications. If you want to share the same set of default applications, you
should create the following symlink:

.. code-block:: bash

    ln -s ~/.local/share/applications/{mimeapps,defaults}.list

**Other programs:**  There may be further steps to take depending on the exakt
set of software that is in use on your system. If you would like to add
something to the list please don't hesitate to send me an email_.


.. _awesome: http://awesome.naquadah.org/

.. _available terminal emulators: https://en.wikipedia.org/wiki/List_of_terminal_emulators#X_Window_Terminals
.. _rxvt: http://rxvt.sourceforge.net/
.. _urxvt: http://software.schmorp.de/pkg/rxvt-unicode.html
.. _xterm: http://invisible-island.net/xterm/xterm.html
.. _terminator: http://gnometerminator.blogspot.de/p/introduction.html

.. _ranger: http://ranger.nongnu.org/
.. _True Color Image previews: https://github.com/hut/ranger/wiki/Image-Previews

.. _on xterm:
.. _on urxvt:
.. _Xresources: https://wiki.archlinux.org/index.php/X_resources

.. _AUR package: https://aur.archlinux.org/packages/rxvt-unicode-better-wheel-scrolling/
.. _Scrollback buffer in secondary screen: https://wiki.archlinux.org/index.php/Rxvt-unicode#Scrollback_buffer_in_secondary_screen

.. _Uvxrt - Vim Arrow- and End-key Problem: http://mightyuhu.github.io/blog/2011/04/19/uvxrt-vim-arrow-and-end-key-problem/

.. _email: mailto:t_glaessle@gmx.de
