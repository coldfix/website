public: yes
tags: [programming, bug, python, async, refcount]
summary: |
  Keep reference to your coroutines!

Fun with generators
===================

Can you imagine why the two generators in the following snippet can behave
very different (in CPython):

.. code-block:: python

    def foo():
        yield Yielded()

    def bar():
        x = Yielded()
        yield x

You guessed it: reference counts. I came across this phenomenon as an
interesting variation of the bug described in `Never trust your reference
count!`_. I encountered the issue described in the present article much
earlier (already in late 2015) and I'm writing about it now because I found it
an intriguing discovery at the time.

.. _`Never trust your reference count!`: /2016/05/14/zombie-dialog/

A short example
~~~~~~~~~~~~~~~

The issue can be observed in the following `minimal example`_. First, note
that we slightly modify the above definitions of ``foo`` and bar – just to
show messages when the action happens:

.. _minimal example: ../minimal.py

.. code-block:: python

    class Yielded:

        def __init__(self, name):
            self.name = name

        def __del__(self):
            print("Delete {}".format(self.name))


    def foo():
        try:
            yield Yielded("foo")        # Transfer control to caller.
            print("After yield: foo")   # This will never be printed.
        except GeneratorExit:
            print("Exit foo")           # Show when generator is closed.
            raise


    def bar():
        try:
            x = Yielded("bar")
            yield x
            print("After yield: bar")
        except GeneratorExit:
            print("Exit bar")
            raise

Now, we invoke ``foo`` and ``bar`` in such a way that no reference chain from
global scope to the generators is kept after having reached the first yield
expression.  However, we store a reference to the generator in the yielded
``Yielded`` instance:

.. code-block:: python

    from asyncio import new_event_loop


    def consume_one(generator):
        x = next(generator)
        x.g = generator


    if __name__ == '__main__':
        mainloop = new_event_loop()
        mainloop.call_later(0.0, consume_one, foo())
        mainloop.call_later(0.0, consume_one, bar())
        mainloop.run_forever()


This means the ``Yielded`` now contains the only reference to the generator.
If we do not take care to create a global reference to the ``Yielded`` it can
be deleted and therefore remove the only reference to the generator. When this
happens, the generator is closed and deleted – triggering a ``GeneratorExit``.

However, ``bar`` keeps a reference to the yielded object in the form of a
local variable ``x``. This establishes a reference cycle between ``bar`` and
``x`` – which means that (contrary to ``foo``) ``bar`` will not be closed
immediately due to reference counting.

On CPython the above program immediately outputs::

    Delete foo
    Exit foo

and then waits indefinitely.


Actual use case
~~~~~~~~~~~~~~~

This example may seem a little far fetched, is there any actual use case?

Yes. A more `realistic example`_ is extracted from a program of mine for which
I hand-made a lightweight asynchronous layer. This was necessary since there
was no stable alternative that could be used with `PyGI`_ (and also I wanted
to keep python2 compatibility) at the time. In the actual code, the issue
described here caused a tray icon to vanish in some cases immediately after
creation and stop a sequence of asynchronous operations.

The protocol was based on ``Async`` objects (replacing ``Yielded``). Similar
to *asyncio* or *Twisted*, sequential execution of several asynchronous tasks
is written with generators, where each ``yield`` expression transfers control
to the yielded task.

The above backreference ``x.g`` to the generator is established by a callbacks
that allows to continue the coroutine after having finished the intermediate
task.

.. _realistic example: ../async.py
.. _PyGI: https://wiki.gnome.org/action/show/Projects/PyGObject


Reliable behaviour?
~~~~~~~~~~~~~~~~~~~

In this application, we want to keep the coroutine alive in order to continue
its execution after the scheduled subtask is done. Does this mean that the
form ``bar`` is more appropriate, i.e. can we rely on ``bar`` not being
deleted?

No. The garbage collector can still detect the reference cycle and clean up
the objects. You can check this out by manually triggering a call to
``gc.collect``:

.. code-block:: python

    import gc

    if __name__ == '__main__':
        ...
        mainloop.call_later(3.0, gc.collect)
        mainloop.run_forever()

The program output will now be::

    Delete foo
    Exit foo

(wait 3s)::

    Exit bar
    Delete bar

This possibility introduces indeterministic behaviour that is hard to debug:
The behaviour will generally be influenced by the insertion of debug
statements or use of *pdb*.

Fixing the bug
~~~~~~~~~~~~~~

The fix is to always ensure that there is a reference chain from a global
scope to your coroutines. In the easiest case, you could just add a global
reference to all executing coroutines. In the `realistic example`_ you could
modify the ``Coroutine`` class like this:

.. code-block:: python
    :emphasize-lines: 3,6,10

    class Coroutine(Async):

        __REFS = []

        def __init__(self, generator):
            self.__REFS.append(self)
            self._generator = generator

        def _close(self):
            self.__REFS.remove(self)
            self._generator.close()
