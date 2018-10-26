tags: [programming, python, gist]
summary: |
  The packed arguments version of ``str.format()``.

Did you know python's ``vformat()``?
====================================

It's to ``str.format()`` what ``vprintf()`` is for ``printf()``. You can get
it like this:

.. code-block:: python

    import string
    vformat = string.Formatter().vformat

It's signature is ``vformat(spec, args, kwargs)`` and it does what you would
think.

Now you may ponder: The convenient argument unpacking in python generally makes
``v``-type functions unnecessary – so why would you need ``vformat`` if you
can write ``spec.format(*args, **kwargs)`` just as easily without additional
import?

This is true if ``args`` and ``kwargs`` are ordinary ``tuple`` and ``dict``.
But the great thing about ``vformat`` is that it doesn't require a full
argument unpacking! This means that you can specify arbitrary objects that
support item access without having to preemptively evaluate the values for all
the keys. Hell, you need not even provide a method to iterate over the keys!

This can be a superb trait, if you have format strings that typically only
access a few properties from a value store with many values – where each of
the values may be easy to retrieve, but getting all of them would pose an
unnecessary overhead if done frequently, e.g.:

.. code-block:: python

    vformat("Mounted {device_presentation} on {mount_path}", (), dbus_device_interface)

(Of course, the same also works for ``args`` parameter, but I see no real
benefit here.)

``vformat`` allows to pass views onto other objects where the view can perform
ad-hoc checks or transformations. For example:

.. code-block:: python

    class View:
        def __init__(self, obj, blacklist):
            self.obj = obj
            self.blacklist = blacklist

        def __getitem__(self, key):
            if key in self.blacklist:
                raise KeyError(key)
            try:
                return getattr(self.obj, 'public_' + key)
            except AttributeError:
                raise KeyError(key)

    # will access `obj.public_x` and `obj.public_y`:
    vformat("{x} {y}", None, View(obj, ATTR_BLACKLIST))

As you see ``vformat()`` allows to do all sorts of things and is much more
powerful than plain ``str.format()``

**Note:** from python 3.2 upwards there is also the easier accessible
``str.format_map(kwargs)`` that is easier to use.
