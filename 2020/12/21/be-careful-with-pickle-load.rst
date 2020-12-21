tags: [coding, python, bug]
summary: |
  Getting UnpicklingError with no chance of recovery

Be careful with ``pickle.load``
===============================

You are probably aware that ``pickle.load`` can execute arbitrary code and
must not be used for untrusted data.

This post is not about that.

In fact, ``pickle.load`` can't even really be trusted for *trusted* data. To
demonstrate the issue, consider this simple program:

.. code-block:: python

    import os, pickle, threading

    message = '0' * 65537

    recv_fd, send_fd = os.pipe()
    read_end = os.fdopen(recv_fd, 'rb', 0)
    write_end = os.fdopen(send_fd, 'wb', 0)

    thread = threading.Thread(
        target=pickle.dump,
        args=(message, write_end, -1))
    thread.start()

    pickle.load(read_end)

This simply transmits a pickled message over a pipe over a pipe.
Looks innocuous enough, right?

Wrong! The program fails with the following traceback every time:

.. code-block:: none

    Traceback (most recent call last):
      File "<...>/example.py", line 16, in <module>
        pickle.load(read_end)
    _pickle.UnpicklingError: pickle data was truncated

Worse: once you get this error, **there is safe way to resume** listening for
messages on this channel, because you don't know how long the first message
really was, and hence, at which offset to resume reading. If you try this, you
invite evil into your home. A typical result of trying to continue reading
messages on the stream may be ``_pickle.UnpicklingError: unpickling stack
underflow``, but I've even seen segfaults occur.

The reason that we get the error in the first place is of course that the
message size above the pipe capacity, which is 65,536 on my system. The
threshold at which you start getting errors may of course be different for
you. Try increasing the message size if you don't see errors at first.

If you are using a channel other than ``os.pipe()``, you might be safe – but I
can't give any guarantees on that. I just can say that I wasn't able to
reproduce the error on my system when exchanging the pipe for a socket or
regular file.

We used a thread here to send us the data, but it doesn't matter if the remote
end is a thread or another process. Also, this is not limited to a specific
python version, or version of the pickle protocol. I could reproduce the same
error with several python versions up to python 3.9, and protocols 1-5.

Workaround
----------

So, how to fix that?

The problem empirically seems to disappear when changing the buffering policy
of the reading end, i.e. by not disabling input buffering:

.. code-block:: diff

    - read_end = os.fdopen(recv_fd, 'rb', 0)
    + read_end = os.fdopen(recv_fd, 'rb')

I haven't inspected the source of the ``pickle`` module, so I can't vouch that
this is reliable.

What I turned out doing is to use the ``pickle.dumps()``/``pickle.loads()``
combination to serialize to/from a bytes object, and manually transmit this
data along with its size over the channel. This has some overhead, but still
performs fine for my use-case:

.. code-block:: python

    import pickle
    from struct import Struct

    HEADER = Struct("!L")

    def send(obj, file):
        """Send a pickled message over the given channel."""
        payload = pickle.dumps(data, -1)
        file.write(HEADER.pack(len(payload)))
        file.write(payload)

    def recv(file):
        """Receive a pickled message over the given channel."""
        header = read_file(file, HEADER.size)
        payload = read_file(file, *HEADER.unpack(header))
        return pickle.loads(payload)

    def read_file(file, size):
        """Read a fixed size buffer from the file."""
        parts = []
        while size > 0:
            part = file.read(size)
            if not part:
                raise EOFError
            parts.append(part)
            size -= len(part)
        return b''.join(parts)

Technically, transmitting the size is redundant with information contained in
the pickle protocol. However, where excessive performance is not an issue
(remember: we are using python, after all), I prefer transmitting the size
explicitly anyway. This evades the complexity of manually interacting with the
pickled frames, avoids dependency on a specific pickle protocol, and would
also make it easy to exchange pickle for any other serialization format here.


Conclusion
----------

Be careful with using ``pickle.dump`` + ``pickle.load`` for RPC. It may result
in an ``UnpicklingError`` from which there seems to be no safe way of recovery
that allows to continue transmitting further messages on the same channel.
This occurs when the message size exceeds a certain threshold.

To avoid this issue, make sure that the channel capacity and buffering policy
works with ``pickle.load``. Alternatively, consider using ``pickle.dumps`` +
``pickle.loads``, and handling the channel layer manually instead.
