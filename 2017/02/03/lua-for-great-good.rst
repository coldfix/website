tags: [lua, wat, quirks]
summary: |
  Why lua is the greatest language in the world.

Using a lua for great power and good
====================================

I love lua for so many reasons: For one, it aims to be different. And then, it
helps us stay in shape by making simple tasks more challenging and keeping us
attentive. This is not just yet another language, in lua we have (no
particular order):

- ``1``-based indexing!
- a powerful one-for-all dictionary+array+object type that abolishes a messy
  datatype hell like the one in python where these things are in separate
  (utterly underpowered) container classes.
- `Yet another name for NULL`_.
- Yet another comment syntax: ``--``
- Sieving of lazy developers who would like to make use of things like an
  extensive standard library. I really hate those.
- `Relative imports`_ to keep us on our toes.
- Making all variables global by default.
- The interactive interpreter forcing us to actually use globals, so we can't
  simply copy-paste if we were impertinent enough to use locals in our actual
  code. This is good to keep us wary! Way too many coding bugs are introduced
  due to copy-paste in other languages!
- `Great error-safety!`_
- `Variadic functions and argument unpacking!`_

.. _Variadic functions and argument unpacking!: https://coldfix.de/2017/02/02/lua-wat/
.. _Relative imports: http://stackoverflow.com/questions/9145432/load-lua-files-by-relative-path

It's quick, it's clean, and it's pure.

Go lua!

Yet another name for NULL
-------------------------

God spoke: *Every language shalt have their own slightly different NULL
thingy.*

And so it was:

- C: ``NULL``
- C++: ``nullptr``
- perl: ``undef``
- python: ``None``
- javascript: ``undefined`` / ``null``
- lua: ``nil``

Great error-safety!
-------------------

Tired of converting strings to numbers?

.. code-block:: lua

    > "1" + "2"
    3.0

Tired of remembering the correct number of function arguments? Lua has your
back:

.. code-block:: lua

    > x = function (a) print(a) end
    > x()
    nil
    > x(1, 2)
    1

Tired of getting exceptions when accessing non-existent entries? No more
worries:

.. code-block:: lua

    > t = {foo="foo"}
    > w = {t.foo, t.bar, t["baz"], t[qux]}
    > print(unpack(w))
    foo

Tired of keeping track of variable names? Need automatic spelling correction?
Lua does it for you (but for now it works only for variables refering to
``nil`` values):

.. code-block:: lua

    > complicated = nil
    > print(coplimated)
    nil


To be fair
----------

Most of the above applause is not specific to lua. In many regards, lua is
very similar to javascript_ and perl.

And I do get, why certain things are the way they are. Lua is supposed to be a
simple, lightweight and portable scripting language that is easy to embed in
arbitrary applications.

And there are neat things about the language too: In fact, I (kind of) do
enjoy the simplicity and differentness of the prototype based object
orientation.

For a more comprehensive list, see `Lua Gotchas`_.

.. _javascript: https://www.destroyallsoftware.com/talks/wat
.. _Lua Gotchas: http://www.luafaq.org/gotchas.html
