public: yes
tags: [lua, functools, variadic, gist]
summary: |
  Another solution for argument packing in lua

Lua Argument Packing – Part II
==============================

This is a follow-up on my `previous post`_ covering argument packing in lua.
My new-found lua foo has allowed me to write a new solution to address the
problem of packing arguments in lua. It is slower (but who cares, right?), but
also somewhat more elegant and insightful.

.. _previous post: ../../../02/02/lua-wat/

A quick reminder: If you write variadic functions and want to save (pack) the
arguments for later use, you should do something more sophisticated than
simply putting them in a table like this:

.. code-block:: lua

    local function bind(f, ...)
        local x = {...} -- BAD!!
        return function()
            return f(unpack(x))
        end
    end

If you do it like this, the number of unpacked values will be undefined in the
presence of ``nil`` values in the argument list.

The `previous post`_ gave a solution using a pair of functions ``pack2()`` and
``unpack2()`` that store and use the number of arguments under a separate
table key. A big flaw in this solution is that it doesn't make any use of
*metatables* (and also that it needs a custom replacement for the builtin
``unpack`` function). As you know, everything is better with metatables.

Fortunately, now that we know the problem with the previous solution, we can
write down a better one:

.. code-block:: lua

    local function pack(...)
        local n = select('#', ...)
        return setmetatable({...}, {
            __len = function() return n end,
        })
    end

which allows to write a correct version of the above function as:

.. code-block:: lua

    local function bind(f, ...)
        local x = pack(...) -- GOOD!!
        return function()
            return f(unpack(x))
        end
    end

Note that this time we can use the builtin ``unpack`` function and don't need
to write our own replacement!
