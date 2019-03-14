tags: [python, pip, installation, setuptools]
summary: |
  Why you should always use pip for installation, and setuptools only for packaging!

No pip → No sip
===============

PyQt5 now provide wheels that allow installing directly from PyPI without ever
touching an installer exe file. This is awesome! And it used to work great
until I ran into this error:

.. code-block:: bash

    ImportError: No module named 'PyQt5.sip'

Weird, I got this error only on an automated build, where I was doing
something like ``python setup.py install`` and having PyQt5 listed there in
the ``install_requires`` field. The log clearly showed that both PyQt5 and
PyQt5-sip were installed and both were on the filesystem.

.. code-block:: bash

    ...
    Processing PyQt5_sip-4.19.14-cp35-cp35m-manylinux1_x86_64.whl
    Installing PyQt5_sip-4.19.14-cp35-cp35m-manylinux1_x86_64.whl to /home/thomas/.local/venvs/tmp35/lib/python3.5/site-packages
    Adding PyQt5-sip 4.19.14 to easy-install.pth file

    Installed /home/thomas/.local/venvs/tmp35/lib/python3.5/site-packages/PyQt5_sip-4.19.14-py3.5-linux-x86_64.egg
    Finished processing dependencies for pyqt5
    ...

After some investigation, I found that the problem can be fixed by letting pip
perform the PyQt installation beforehand, e.g.:

.. code-block:: bash

    pip install PyQt5

But what is the reason? It has to do with the fact that ``PyQt5.sip`` was split
into a separate package from ``PyQt5``.

Now, under the hood, ``setup.py`` uses ``easy_install`` to install
dependencies, which installs the namespace package ``PyQt5`` and ``PyQt5.sip``
as separate eggs, but fails to properly setup a namespace package that would
leave sip importable even after the main package was imported.

Pip, on the other hand, just installs the contents of both packages into the
same folder, which means that sip can be found without problem.

I can reproduce this on my machine. In a fresh virtualenv:

.. code-block:: bash

    % easy_install pyqt5
    [...]
    % python -c 'import PyQt5.QtWidgets'
    Traceback (most recent call last):
      File "<string>", line 1, in <module>


Conclusion
~~~~~~~~~~

The lesson is clear: pip and setuptools behave very different when used to
install packages.

Since pip is a dedicated installer, it is often superior and should be the
preferred mode of installation, even during development. I suggest always
using ``pip install`` over the ``python setup.py`` command, even if you have
the package checked out locally, i.e replace:

.. code-block:: bash

    # don't:
    python setup.py install
    python setup.py develop

    # do instead:
    pip install .
    pip install . -e

With the introduction of wheels, the responsibilities became clearer than ever
before:

- The job of setuptools is to **build** packages on the developer machine.
- The job of pip is to **install** packages.

Preferrably you would distribute wheels for all your packages, even in the
case of simple pure python packages without C extensions. The end-user should
not even need to run any setup script on their machine or even have setuptools
installed in most cases. To this end, I don't think there is hardly any reason
to write ``distutils.core`` based setup scripts anymore.
