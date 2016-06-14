
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


def consume_one(generator):
    x = next(generator)
    x.g = generator


from asyncio import new_event_loop
import gc

if __name__ == '__main__':
    mainloop = new_event_loop()
    mainloop.call_later(0.0, consume_one, foo())
    mainloop.call_later(0.0, consume_one, bar())
    mainloop.call_later(3.0, gc.collect)
    mainloop.run_forever()
