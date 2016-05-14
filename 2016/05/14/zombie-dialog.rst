public: yes
tags: [programming, bug, debugging, python, gui, zombie]
summary: |
  Fun with bugs - a story about zombie dialogs.

Never trust your reference count!
=================================

One of the cool things about programming is finding bugs. Personally, I prefer
bugs that catch me by surprise or display astonishing symptoms. Bugs can be
particularly refreshing if your own code is at fault, possibly that one
seemingly well-thought-out piece that you'd think to be fine - until reality
catches up and teaches you otherwise. The permanent testimony of your own
inabilities helps keeping you humble - a feeling that I'd like to share with
you by telling you about the sweetest cherries I find. This is my first post
of this kind, about a bug I encountered this week.

The program
~~~~~~~~~~~

Consider the following simple program that shows a dialog with a single button
and quits the application once the button is clicked.
You will need python-gobject_ to run the example. Both python 2.7 and 3.5
should work fine:

.. _python-gobject: https://wiki.gnome.org/action/show/Projects/PyGObject?action=show&redirect=PyGObject


.. code-block:: python

    # import PyGI (GUI) modules
    from gi import require_version
    require_version('GLib', '2.0')
    require_version('Gtk', '3.0')
    from gi.repository import GLib, Gtk


    def main():
        mainloop = GLib.MainLoop()
        # Show dialog:
        Dialog().on_click_handlers.append(mainloop.quit)
        # Meanwhile, do some work in the background, every 10ms:
        GLib.timeout_add(10, do_some_work)
        # Run until button is clicked:
        mainloop.run()


    class Dialog(object):

        """Simple Dialog with one clickable button."""

        def __init__(self):
            self.window = Gtk.Window(title='Hello World!')
            self.button = Gtk.Button(label='Click Here!')
            self.window.add(self.button)
            self.window.show_all()
            self.button.connect("clicked", self.button_clicked)

        def button_clicked(self, widget):
            """Execute all registered callbacks."""
            for callback in self.on_click_handlers:
                callback()

        @property
        def on_click_handlers(self):
            """List of onclick handlers. Create only on demand."""
            if not hasattr(self, '_callbacks'):
                self._callbacks = []
            return self._callbacks


    def do_some_work():
        """Do very important stuff."""
        # Work, work:
        l = []
        l.append(l)
        # Schedule for re-execution:
        return True


    if __name__ == '__main__':
        main()


The program appears simple enough - so what's the problem?

If you click the button as soon as the window appears, the program will
usually exit as intended - but if you wait a few seconds without clicking,
the program will do nothing more in reply. Try it out! (You have to wait about
3s on py2 and about 10s on py3)

Wait, wat? Why would this happen?

Debugging
~~~~~~~~~

It looks like either ``button_clicked`` is not executed or the list of
callback handlers is cleared. My initial thought was even that the reference
count of the callback handler (here ``mainloop.quit``) may have been somehow
decreased, leading to its destruction and therefore preventing its execution
(the background work was done in a C library which I did not ultimately
trust).

Let's investigate: Insert a few debugging statements in ``Dialog``, strip
``do_some_work`` to its essential functionality and execute it only once. The
following modified code will make clear what's going on:


.. code-block:: python

    from gi import require_version
    require_version('GLib', '2.0')
    require_version('Gtk', '3.0')
    from gi.repository import GLib, Gtk

    import weakref


    def main():
        mainloop = GLib.MainLoop()
        # Show dialog:
        Dialog().on_click_handlers.append(mainloop.quit)
        # Meanwhile, do some work in the background, every 10ms:
        GLib.timeout_add(2000, do_some_work)
        # Run until button is clicked:
        mainloop.run()


    REFS = []

    def death_note(ref):
        print("RIP: dialog, it was time. ({})".format(ref))


    class Dialog(object):

        """Simple Dialog with one clickable button."""

        text = "There is no one here"

        def __init__(self):
            self.window = Gtk.Window(title='Hello World!')
            self.button = Gtk.Button(label='Click Here!')
            self.window.add(self.button)
            self.window.show_all()
            self.button.connect("clicked", self.button_clicked)
            self.text = "I am alive"
            REFS.append(weakref.ref(self, death_note))

        def button_clicked(self, widget):
            print("{}: {}".format(self.text, self.on_click_handlers))

        @property
        def on_click_handlers(self):
            """List of onclick handlers. Create only on demand."""
            if not hasattr(self, '_on_click'):
                print("Creating on_click_handlers.")
                self._on_click = []
            return self._on_click


    def do_some_work():
        import gc
        print("Before gc.collect()!")
        gc.collect()
        print("After gc.collect()!")
        # No need to execute this again:
        return False


    if __name__ == '__main__':
        main()


Run the program and immediately click the button. You get, as expected:

.. code-block:: log

    Creating on_click_handlers.
    I am alive: [gi.FunctionInfo(quit)]

Now wait 2s for the timer to fire:

.. code-block:: log

    Before gc.collect()!
    RIP: dialog, it was time. (<weakref at 0x7f7d52ea5208; dead>)
    After gc.collect()!

Wow, the dialog is dead! Panicking, you repeatedly click the button:

.. code-block:: log

    Creating on_click_handlers.
    There is no one here: []
    There is no one here: []
    There is no one here: []
    There is no one here: []

The dialog has zombified. It can still act, but its former memory, its
personality is lost.

Diagnosis: Death
~~~~~~~~~~~~~~~~

All that's left to do is find someone to blame. How is it possible that the
dialog is still visible, but left to die?

Apparently, the PyGI GTK binding does not hold a reference to the Gtk.Dialog
object. Neither does it increase the reference count of the button-"clicked"
signal handler which it does remember to call.
In consequence, the dialog is only kept alive by a cyclic reference between
the dialog and the signal handler itself (the handler is a bound method and
therefore stores a reference to the dialog object). The garbage collector can
detect such a cycle and delete both objects.

You ask why? Bad design, I'd say. I've seen similar behaviour in other
components, such as libnotify bindings. The result is always that some
callback is executed which belongs to a dead python object.

But why did the dialog come back to live and behave almost as back in the days
- instead of e.g. just crashing the program? I guess that's just coincidence
that the corresponding memory was not overwritten yet.


Bugfix
~~~~~~

How can you fix the problem in your code? The answer is simple and
unsatisfying: Just add a global reference to the dialog object:


.. code-block:: python

    class Dialog(object):

        _INSTANCES = []

        def __init__(self):
            self._INSTANCES.append(self)


And don't forget ``self._INSTANCES.remove(self)`` when getting rid of the
dialog to allow cleaning it up.


The lesson
~~~~~~~~~~

- Never trust third-party libraries to increase the reference count of
  something, just because they use it later on.
- Even familiar bugs can appear in unknown varieties, keeping them fresh and
  fun.
- Don't get lulled into a false sense of security that dead things stay dead!
