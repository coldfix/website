"""
Cut-down example for an application where the bug appears.

Invoke as:

    python3 async.py

Output:

    Leaving scope: foo
    timer: 0
    timer: 1
    timer: 2
    timer: 3
    timer: 4
    timer: 5
    Leaving scope: bar
    timer: 6
    timer: 7
    timer: 8
    timer: 9
    timer: 10
    ....
"""

from functools import wraps


class Async(object):

    """
    Base class for asynchronous operations. One `Async' object represents an
    asynchronous operation. Tasks must take care to increase their reference
    count on their own in order not to be deleted until completion.
    """

    # cachedproperty:
    @property
    def callbacks(self):
        try:
            callbacks = self._callbacks
        except AttributeError:
            callbacks = self._callbacks = []
        return callbacks

    def start(self, event_loop):
        pass

    def set_result(self, *values):
        return [fn(*values) for fn in self.callbacks]


class Return(object):

    def __init__(self, value):
        self.value = value


class Coroutine(Async):

    """
    A coroutine processes a sequence of asynchronous tasks. The coroutine's
    code block will first be entered in a separate main loop iteration.

    Coroutines are implemented as generators using `yield` expressions to
    transfer control flow when performing asynchronous tasks. Coroutines may
    yield zero or more `Async` tasks and one final `Return` value.
    """

    @classmethod
    def generator_function(cls, generator_function):
        """Turn a generator function into a coroutine function."""
        @wraps(generator_function)
        def coroutine_function(*args, **kwargs):
            return cls(generator_function(*args, **kwargs))
        coroutine_function.__func__ = generator_function
        return coroutine_function

    def __init__(self, generator):
        """Create and start a `Coroutine` task from the specified generator."""
        self._generator = generator

    def start(self, event_loop):
        event_loop.call_later(0.0, self._interact, next, self._generator)
        self.event_loop = event_loop

    def _close(self):
        self._generator.close()

    def _recv(self, thing):
        """Handle a value received from (yielded by) the generator."""
        # This function is called immediately after the generator suspends
        # its own control flow by yielding a value.
        if isinstance(thing, Async):
            # when the yielded async is done, continue this coroutine:
            thing.callbacks.append(self._send)
            thing.start(self.event_loop)
        elif isinstance(thing, Return):
            self._close()
            self.set_result(thing.value)

    def _send(self, value):
        """Interact with the coroutine by sending a value."""
        # Set the return value of the current `yield` expression to the
        # specified value and resume control flow inside the coroutine.
        self._interact(self._generator.send, value)

    def _interact(self, func, arg):
        """Execute to the next yield expression and handle yielded value."""
        try:
            value = func(arg)
        except StopIteration:
            self._close()
            self.set_result(None)
        else:
            self._recv(value)


class ScopeGuard(object):
    # This could be a GUI element like `gi.repository.Gtk.StatusIcon` which
    # gets destroyed as soon as the application does not store a reference to
    # it anymore.
    def __init__(self, name): self.name = name
    def __del__(self): print("Leaving scope: {}".format(self.name))


class WaitForever(Async):
    # The most simple Async - never schedules its `set_result()` method for
    # execution and therefore just waits indefinitely.
    pass


@Coroutine.generator_function
def foo():
    guard = ScopeGuard("foo")
    yield WaitForever()


@Coroutine.generator_function
def bar():
    guard = ScopeGuard("bar")
    wait = WaitForever()
    yield wait


class Sleep(Async):

    def __init__(self, time):
        self.time = time

    def start(self, event_loop):
        event_loop.call_later(self.time, self.set_result, True)


@Coroutine.generator_function
def show_timer(time):
    i = 0
    while True:
        print("timer: {}".format(i))
        yield Sleep(time)
        i += 1


def main():
    import gc
    import asyncio

    mainloop = asyncio.new_event_loop()
    foo().start(mainloop)
    bar().start(mainloop)
    show_timer(1.0).start(mainloop)
    mainloop.call_later(3.5, gc.collect)
    mainloop.run_forever()


if __name__ == '__main__':
    main()
