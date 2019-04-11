tags: [python, pip, installation, setuptools]
summary: |
  and leave ``setup.py`` for packaging only

Always use pip for installation!
================================

**TL;DR:** Always prefer ``pip install [-e] .`` over the corresponding
``setup.py install/develop`` command! It does a lot more things right than you
might know. Leave ``setup.py`` for packaging only. In the previous post `No
Pip → No Sip`_, I gave already one compelling reason for this. If you thought
*more, there must be more*, you are exactly right. The most relevant are:

- creates faster starting scripts for ``entry_points``
- installs ``data_files`` to the correct location
- handles namespace packages better
- can result in faster import times overall
- leaves the developer room to use non-trivial setup dependencies

In the following, when I say that *setuptools does X*, I mean what happens if
directly running ``setup.py install`` as opposed ``pip install``,
independently of whether setuptools is imported within the setup script or
not.

I hope that by the end of the article I will have fully convinced you to leave
out the ``python setup.py install`` command from installation instructions
from now on!

Before we get started, let's discuss how these installation modes differ. Both
(usually) install distributions to subfolders under the site-packages
directory. The difference is in how they setup the directory structure:

- setuptools creates a ``.egg`` subdirectory (or zip archive) for each
  distribution, into which it then installs all files. For example the module
  ``a.b.c`` is installed as ``site-packages/PKG.egg/a/b/c.py``, (``PKG`` being
  the name of the distribution, not the importable python package).

- pip creates a ``PKG.dist-info`` metadata folder for each distribution, but
  installs python sources separately under the name of the import package
  directly under site-packages. For example the python module ``a.b.c`` is
  installed as ``site-packages/a/b/c.py``.

Now we are ready to understand more arguments for recommending ``pip install``
over ``setup.py`` usage! Here are some:

0. setuptools installs python sources from different distributions
   corresponding to the same namespace packages into separate folders while
   pip merges them into the same source folder. The setuptools behaviour leads
   to the issue discussed in the previous post `No pip → No sip`_; may pose
   further potential pathing problems; makes it harder to get an overview over
   all installed submodules/subpackages as a user by browsing the filesystem

1. installing to eggs can lead to greater startup/import times due requiring
   the import machinery to search through multiple eggs, instead of limiting
   the search scope to one well defined location.

2. pip installs application entrypoints with a fast entrypoint script, whereas
   setuptools installs a script that imports ``pkg_resources`` as part of its
   loading procedure. This can add (depending on your hardware and number of
   installed packages) up to seconds to the application startup process. See
   also my earlier post `Don't use setuptools entry points…`_

3. pip installs ``data_files`` into the (arguably) correct location, i.e.
   relative to ``sys.prefix`` rather than into the egg directory (as
   setuptools does). This is important if you want to install documentation,
   man pages, shell completions, vim syntax highlighting, or other data that
   should be accessible by other (non-python) programs. While there are hacks
   to to make setuptools install data files to ``sys.prefix`` (e.g. by
   subclassing the ``install`` command, even without any further changes),
   this increases the complexity of the setup script, and, more importantly:

4. setuptools does not keep record of installed files, which
   makes it impossible to completely uninstall a distribution that has data
   files outside of the ``.egg`` directory. In contrast, pip creates a list of
   all installed files which makes it easy to fully remove a pip installation.

5. by fully appreciating that the ``setup.py`` script is not to be touched by
   the average user, you as a developer can avoid the chicken-egg problem of
   having to install setup time dependencies before running the setup script
   (such as cython or even setuptools itself): For one, it is easier to direct
   a few fellow developers to manually install setup dependencies, than
   complicate installation for all users, but even better, pip can deal with
   the `PEP 518`_ (a.k.a. ``pyproject.toml``) mechanism to allow arbitrary
   build systems and preinstall required dependencies.

Minor addendum to the last point: There is no more need to be hesitant to use
setuptools in your ``setup.py`` script! In fact, I would recommend *always*
using setuptools, even for simple pure python projects, because it allows the
creation of wheels.

Of course, pip has loads of additional advantages for users, e.g.:

- has more powerful options in how to deal with dependencies (e.g. whether to
  install and where from), and where to install to

- caches downloaded distributions

- makes it easy to perform offline installations by using ``pip download`` or
  ``pip wheel`` to prepare the package and all dependencies.

.. _No pip → No sip: /2019/03/14/no-pip-no-sip.rst
.. _Don't use setuptools entry points…: /2017/02/25/slow-entrypoints.rst
.. _PEP 518: https://www.python.org/dev/peps/pep-0518/
