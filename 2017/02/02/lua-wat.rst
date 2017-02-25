public: yes
tags: [lua, wat, quirks, fun]
summary: |
  Where lua got it right: Variadic functions and argument unacking!

Lua — Wat?!‽
============

.. contents:: :local:

As simple as it gets
--------------------

Take a minute to contemplate this fine piece of lua, making use of the ``...``
syntax for variadic functions and the builtin ``unpack()`` function:

.. code-block:: lua

    local function bind(f, ...)
        local x = {...}
        return function()
            return f(unpack(x))
        end
    end

Now what do we have here?

Right, it takes a function and some arguments and returns a callable that,
when invoked, will call the function with said arguments. It's a basic version
of what is called in python a partial.

Looks simple enough, but does it work?

Sure it does, lets see:

.. code-block:: lua

    > bind(print, 1, 2)()
    1 2

    > bind(print, 1, 2, 3)()
    1 2 3

Great!

But what happens if we pass in a ``nil``?

.. code-block:: lua

    > bind(print, 1, 2, 3, nil)()
    1 2 3

Okay, it gets swallowed. So, a ``nil`` terminates the argument list. Got it!

.. code-block:: lua

    > bind(print, 1, 2, 3, nil, 5)()
    1   2   3   nil 5

Oh, nevermind. The truth is: only a *trailing* ``nil`` will not be forwarded
as an argument.

.. code-block:: lua

    > bind(print, 1, 2, 3, nil, 5, nil)()
    1   2   3

I meant, a trailing ``nil`` terminates the argument list at the first
occurence of a ``nil``.

.. code-block:: lua

    > bind(print, 1, 2, 3, nil, 5, nil, 7)()
    1   2   3   nil 5   nil 7

    > bind(print, 1, 2, 3, nil, 5, nil, 7, nil)()
    1   2   3

    > bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9)()
    1   2   3   nil 5   nil 7   nil 9

What I thought, it's all consistent!

.. code-block:: lua

    > bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9, nil)()
    1   2   3   nil 5   nil 7

Okay, lua is much smarter than I thought. I guess, the actual rule of thumb
is: a trailing ``nil`` terminates the argument list at first ``nil``, unless
its the fourth ``nil``, then it terminates at the third. Makes sense to me!

.. code-block:: lua

    > bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9, nil, nil)()
    1   2   3   nil 5

Oh, this will be easy to integrate in the mental ruleset.

.. code-block:: lua

    > bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9, nil, nil, nil)()
    1   2   3

    > bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9, nil, nil, nil, nil)()
    1   2   3

    > bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9, nil, nil, nil, nil, nil)()
    1   2   3   nil 5   nil 7

    > bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9, nil, nil, nil, nil, nil, nil)()
    1   2   3   nil 5   nil 7   nil 9

This is even easier to predict than ever anticipated. :)

Note, this feature works on ``lua 5.1-5.3``.

The complete code
-----------------

Again, the complete code-example_ looks like this:

.. _code-example: ../LUAWAT.lua

.. code-block:: lua

    local function bind(f, ...)
        local x = {...}
        return function()
            f(unpack(x))
        end
    end

    bind(print, 1, 2)()
    bind(print, 1, 2, 3)()
    bind(print, 1, 2, 3, nil)()
    bind(print, 1, 2, 3, nil, 5)()
    bind(print, 1, 2, 3, nil, 5, nil)()
    bind(print, 1, 2, 3, nil, 5, nil, 7)()
    bind(print, 1, 2, 3, nil, 5, nil, 7, nil)()
    bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9)()
    bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9, nil)()
    bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9, nil, nil)()
    bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9, nil, nil, nil)()
    bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9, nil, nil, nil, nil)()
    bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9, nil, nil, nil, nil, nil)()
    bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9, nil, nil, nil, nil, nil, nil)()

And the corresponding output:

.. code-block:: txt

    1   2
    1   2   3
    1   2   3
    1   2   3   nil 5
    1   2   3
    1   2   3   nil 5   nil 7
    1   2   3
    1   2   3   nil 5   nil 7   nil 9
    1   2   3   nil 5   nil 7
    1   2   3   nil 5
    1   2   3
    1   2   3
    1   2   3   nil 5   nil 7
    1   2   3   nil 5   nil 7   nil 9


Do not use *this*
-----------------

For the love of all that is good and descent, if you have any sanity left,
please don't use this `bugged variant`_ of ``bind``:

.. _bugged variant: ../bugged_bind.lua

.. code-block:: lua

    -- pack function arguments. Use unpack2() for unpacking! This differs
    -- from the builtin method `x = {...}; unpack(x)` in that it unpacks the
    -- correct number of arguments, even in the presence of nil values.
    function pack2(...)
        return {n = select('#', ...), ...}
    end

    -- unpack function arguments that were packed by pack2()
    function unpack2(t, start)
        return unpack(t, start, t.n)
    end

    -- concat two parameter packs that were packed by pack2. This is
    -- necessary to prevent multiple nils being joined at the end of the first
    -- pack.
    function pack_concat(a, b)
        local ret = {n = a.n+b.n, unpack2(a)}
        for i = 1, b.n do
            ret[a.n+i] = b[i]
        end
        return ret
    end

    -- bind initial arguments to a function (partial)
    -- bind(f, x)(y) = f(x, y)
    function bind(func, ...)
        local head = pack2(...)
        return function(...)
            local tail = pack2(...)
            local args = pack_concat(head, tail)
            return func(unpack2(args))
        end
    end

It delivers completely unpredictable output such as this:

.. code-block:: txt

    1   2
    1   2   3
    1   2   3   nil
    1   2   3   nil 5
    1   2   3   nil 5   nil
    1   2   3   nil 5   nil 7
    1   2   3   nil 5   nil 7   nil
    1   2   3   nil 5   nil 7   nil 9
    1   2   3   nil 5   nil 7   nil 9   nil
    1   2   3   nil 5   nil 7   nil 9   nil nil
    1   2   3   nil 5   nil 7   nil 9   nil nil nil
    1   2   3   nil 5   nil 7   nil 9   nil nil nil nil
    1   2   3   nil 5   nil 7   nil 9   nil nil nil nil nil
    1   2   3   nil 5   nil 7   nil 9   nil nil nil nil nil nil
