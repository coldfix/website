public: no
tags: [programming, idiom, python, functional]
summary: |
  Write more list comprehensions!


An unforgettable family reunion
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To make the next family reunion perfect, you are asked to *write a function
that (given a list of numbers) computes the sum of quotients of the prime
factors of the odd numbers in the list with exactly two prime factors*.

We assume that your grandma has already defined an awesome ``prime_factors``
function for you that returns all prime factors of a given number in ascending
order. This function is in fact implemented by delegating the computation
through a remote procedure call into grandma's cyber interface that asks her
to perform the job by hand; and then waiting for her boot up her brand-new 486
PC, scan the results, run an optical character recognition software on her
handwriting and send it back to the main process by email. The technology is
amazing but it can take a second or two, so you generally don't want to
compute this function twice for any given number.

Your father wants to help. He is a very imperative person and so is his
solution:

.. code-block:: python

    def sum_of_prime_factor_quotients(numbers):
        sum_ = 0
        for num in numbers:
            if num % 2 != 0:
                factors = prime_factors(num)
                if len(factors) == 2:
                    a, b = factors
                    sum_ += b / a
        return sum_

You, however, like functional style of programming mathematical functions. So
you try to rewrite this using list comprehensions. However, there is a minor
obstactle: python has no syntax for inline assignment to variables within
list-comprehensions. This makes writing a function like this a bit uneasy.

Your brother suggest to write it using a nested map, i.e.:

.. code-block:: python

    def odd(num):
        return num % 2 != 0

    def sum_of_prime_factor_quotients(numbers):
        return sum(factors[1] / factors[0]
                   for factors in map(prime_factors, filter(odd, numbers))
                   if len(factors) == 2)

And indeed, this is a viable solution.

However, you find it somewhat awkward and hard to read, and it doesn't name
the individual factors. And this will even get worse, if you later find that
you may need additional arguments for the filter or map.

Your mother, coming from Haskell, would like to write it this way:

.. code-block:: python
    :emphasize-lines: 5,7

    def sum_of_prime_factor_quotients(numbers):
        return sum(a / b
                   for num in numbers
                   if  num % 2 != 0
                   def factors = prime_factors(num)
                   if  len(factors) == 2
                   def a, b = factors)

But when you tell her that there is no such syntax, she explains that the
syntax she suggested is in fact just a shorthand for the following:

.. code-block:: python
    :emphasize-lines: 5,7

    def sum_of_prime_factor_quotients(numbers):
        return sum(a / b
                   for num in numbers
                   if  num % 2 != 0
                   for factors in [prime_factors(num)]
                   if len(factors) == 2
                   for a, b in [factors])

Note how inline assignments are equivalent to iterations over single-element
lists!

Now everyone is happy and set for a great celebration.

**The End.**
