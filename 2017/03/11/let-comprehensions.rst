public: yes
tags: [programming, idiom, python, functional]
summary: |
  Write more list comprehensions!

Let assignments in list comprehensions
======================================

List comprehensions and its kin (i.e. dict/set comprehensions or generator
expressions) are a powerful means to write functions returning lists and such
in a concise and abstract, functional style.

One thing that seems to be missing in python's list comprehensions is the
ability to **assign names to intermediate values**. This can be useful to
avoid recomputation of expensive functions or to make the code easier to read
(e.g. when expressions become to lengthy) – without introducing separate
functions.

It turns out, although this feature is not supported natively, it can be
emulated easily, even though it is not quite as beautiful as the ``let``
assignments in Haskell.

This post comes in two variants:

- Rookie_: featuring a very realistic and concrete example, lots of nonsense
  talking, a great story-line and nothing behind.
- Know-it-all_: for those who just want to get to the point and feel confident
  with concise and more abstract examples.

.. _Rookie: ../an-unforgettable-family-reunion/


Know-it-all
~~~~~~~~~~~

To avoid recomputation of ``f(x)`` in list-comprehensions such as this:

.. code-block:: python

    [h(x, f(x))
     for x in X
     if g(x, f(x))]

You would like to have inline assignment to variables. But this doesn't exist
in python:

.. code-block:: python
    :emphasize-lines: 3

    [h(x, y)
     for x in X
     def y = f(x)
     if g(x, y)]

However, you can write instead:

.. code-block:: python
    :emphasize-lines: 3

    [h(x, y)
     for x in X
     for y in [f(x)]
     if g(x, y)]

In fact, this is nothing new. Haskell's list-comprehensions are just syntactic
sugar for the list monad. With this perspective, Haskell's ``let`` assignments
can be implemented using the ``return`` function of the list-monad – which
means putting a value in a minimal list-context, i.e. ``return v = [v]``.

Know your options
~~~~~~~~~~~~~~~~~

Of course, there are more ways of writing the above function.

Imperative style (ugh…):

.. code-block:: python

    l = []
    for x in X:
        y = f(x)
        if g(x, y):
            l.append(h(x, y))

Nesting:

.. code-block:: python

    [h(x, y)
     for x, y in [(x, f(x)) for x in X]
     if g(x, y)]

If ``X`` does not get consumed when iterating over, you can write:

.. code-block:: python

    [h(x, y)
     for x, y in zip(X, map(f, X))
     if g(x, y)]

    # or even:
    map(h, filter(g, zip(X, map(f, X))))


If ``g`` and ``h`` are independent of ``x``, this becomes simpler:

.. code-block:: python

    [h(y)
     for y in map(f, X)
     if g(y)]

    # or even:
    map(h, filter(g, map(f, X)))
