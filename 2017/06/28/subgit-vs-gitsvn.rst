tags: [git, svn, migration, subgit, git-svn, svn2git]
summary: |
  subgit vs svn2git?

git: migrate SVN to git
=======================

Today's post covers the conversion process of large SVN repositories to git.

This is one of a series of posts where I want to share my experiences from
converting the MAD-X_ SVN_ repository with roughly 6300 revisions and 370
branches and tags. So if you want to convert a large multi-branch/tag
repository, keep reading.

.. contents:: :local:
    :depth: 1

If you're interested in methods to reduce the converted repository's weight
before publishing the final version, you may also find git-du_, git-unpack_,
git-dir2mod_ articles useful.

.. _MAD-X:          https://github.com/MethodicalAcceleratorDesign/MAD-X
.. _SVN:            http://svnweb.cern.ch/world/wsvn/madx
.. _git-du:         /2017/05/30/git-du/
.. _git-unpack:     /2017/06/11/git-unpack/
.. _git-dir2mod:    /2017/06/13/git-dir2mod/

subgit vs svn2git
-----------------

There are plenty_ of posts_ describing how to convert SVN repositories to git
using git-svn_ or svn2git_ (which is based on the former). In my experience,
however, these tools do not perform well for large SVN repositories,
specifically if there are multiple branches.

I strongly recommend to use subgit_ instead. The main reasons to prefer this
tool are:

.. _plenty: https://john.albin.net/git/convert-subversion-to-git
.. _posts: https://www.getdonedone.com/converting-5-year-old-repository-subversion-git/
.. _git-svn: https://git-scm.com/docs/git-svn
.. _svn2git: https://github.com/nirvdrum/svn2git
.. _subgit:  https://subgit.com/

Performance
~~~~~~~~~~~

*git-svn* and *svn2git* are extremely slow when working with multiple branches
or tags: they read through the entire history multiple times. I cancelled the
after about 6 hours into the process when it was still not finished.

On the other hand *subgit* went through the revisions only once and the whole
import was finished in less than 5 minutes.

Branch structure
~~~~~~~~~~~~~~~~

subgit seems to be better at correctly representing merge structures in git.
For example, I had a branch that was merged like this::

    o---o---o---o---o  trunk
         \       \
          A---o---B---o---o  next

for which the svn2git conversion failed to detect the merge and instead
yielded a commit structure like this::

    o---o---o---o---o  trunk
         \
          A---o---B---o---o  next

The subgit generated commits looked as expected.

Authors
~~~~~~~

With *git-svn*, you have to manually create a list of authors by accessing the
SVN log (as described in the linked posts and the svn2git README). *subgit*
does this job for you and creates one in the ``REPO/subgit/authors.txt``
directory – one less thing to worry about.

Branch detection
~~~~~~~~~~~~~~~~

subgit seems to be pretty good at auto-detecting branches in the ``branches/``
folder – even for inconsistent/non-standard folder layout. For example, the
repository that I converted had the actual source code living in
``trunk/madX`` and some of the branches had the code in
``branches/foo/madX`` others directly under ``branches/bar``. subgit was able
to correctly deduce the branches paths by using the ``--layout auto`` option.

Mirror the SVN repo
-------------------

Let's talk business. Before importing the SVN repository to git, it is useful
to create a mirror of the repository on the local machine in order to improve
performance of subsequent accesses.

This can be done using at least three basic methods, with a strong preference
on the third one:

1. dump using svnadmin
~~~~~~~~~~~~~~~~~~~~~~

If you have direct access to the host from which the SVN repository is served,
you can dump it and then import:

.. code-block:: bash

    ssh HOST svnadmin PATH > dump
    svnadmin create repo-svn
    svnadmin load repo-svn < dump

2. dump using rsvndump
~~~~~~~~~~~~~~~~~~~~~~

(not recommended)

If you don't have direct access, you can do the same using ``rsvndump`` with
the root address of the repository:

.. code-block:: bash

    rsvndump SVN_URL > dump
    svnadmin create repo-svn
    svnadmin load repo-svn < dump

However, note that for some reason the ``rsvndump`` operation needed about
16GiB in my ``/tmp`` when doing this. If you need to do this, be prepared to
switch on additional swaps and remount your ``/tmp`` with more space or
directly mount ``/tmp`` from disc.

..  fallocate -l 20G swapfile
..  mkswap swapfile
..  swapon swapfile
..  mount -o remount
..  mount -o remount,size=20G /tmp

3. synchronize using svnsync
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This is the preferred option.

.. code-block:: bash

    svnadmin create repo-svn
    cd repo-svn
    echo '#!/bin/sh' > hooks/pre-revprop-change
    chmod +x hooks/pre-revprop-change
    svnsync init file://`pwd` SVN_URL
    svnsync sync file://`pwd`
    cd -

Note that with this method you can easily pull new commits on the SVN upstream
into your mirror by re-issueing the final ``svnsync sync`` command.

Finally
~~~~~~~

Finally, make the SVN mirror accessible on ``svn://localhost:3030``:

.. code-block:: bash

    svnserve --root repo-svn --listen-port 3030 -d

Subgit migration
----------------

Use subgit to convert your local SVN mirror into a git repository:

.. code-block:: bash

    subgit configure svn://localhost:3030 repo-git --trunk trunk/madX --layout auto

Before continuing, inspect the file ``repo-git/subgit/config`` and fill
``repo-git/subgit/authors.txt`` with the correct names and email addresses
corresponding to the SVN users.

We can now import the commits using the command:

.. code-block:: bash

    subgit install repo-git

Note that subgit will continue to synchronize the resulting ``repo-git`` git
repository. This means that before further working with this repository you
should either ``subgit uninstall repo-git`` – or better clone it to a new
location where your modifications will stick:

.. code-block:: bash

    git clone --mirror repo-git repo-clone

You are now free to work on the repository in ``repo-clone``. This is useful
if you e.g. need to apply ``git filter-branch`` to make final adjustments
before publishing the git repository.

Add revision numbers
--------------------

You can add revision numbers to the commit messages like so:

.. code-block:: bash

    cd repo-clone
    git filter-branch --msg-filter '
        REV=$(git log --format="%N" $GIT_COMMIT -1 | cut -d" " -f1)
        echo -n "$REV: "
        cat
    ' -- --branches --tags

Polish before publish
---------------------

In order to cut the repository size from about 380MiB to just over 100MiB, we
performed a few additional operations on the MAD-X repository, making use of
the git-filter-tree_ module to implement these operations efficiently:

.. code-block:: bash

    git clone https://github.com/coldfix/git-filter-tree

For more info stick to the posts linked at the top of the page.

.. _git-filter-tree: https://github.com/coldfix/git-filter-tree

While you may have very different requirements this is to give you some ideas
what can be done:

- remove some PDF files using:

.. code-block:: bash

    python ../git-filter-tree/git_filter_tree rm \
        doc/latexuguide/madxuguide.pdf \
        ... \
        doc/usrguide/reports/reference.ps \
        -- --branches --tags

- unpack ``.gz`` ascii files:

.. code-block:: bash

    python ../git-filter-tree/git_filter_tree unpack \
        -- --branches --tags

- convert subdirectory into submodule:

.. code-block:: bash

    ./git-filter-tree/git-dir2mod \
        repo-clone subdir \
        SUBMODULE_URL \
        repo-parent repo-submod

Migrating issues
----------------

I looked at a few alternative tools for migrating issues. In the end I settled
for trac-hub_ for the following reasons:

- support for attachments
- support for labels
- easy to modify

In fact, the last point turned out to be the key strength by far. I ended up
patching most of the system for my own needs and completely changing the
logic. The changes are now all integrated in the upstream so you don't have to
worry about which one to choose.

The tool now uses githubs new issue import API which allows to perform the
whole process…

- …without hitting abuse detection warnings and getting blocked
- …without sending email notifications
- …without increasing your contribution count for each migrated issue
- …much faster than with the `normal issues API`_
- …with correct creation/closed date set
- …atomically without users being able to interfere in the creation of any
  single issue

For MAD-X, I decided to put all comments on an issue in the body of the
initial post to make it more concise and readable and avoid putting my name on
every message. For an example of how this looks, see e.g. here_. This
behaviour can be selected by using the ``-S`` flag.

.. _trac-hub:   https://github.com/mavam/trac-hub
.. _normal issues API: https://developer.github.com/v3/issues/
.. _here:       https://github.com/MethodicalAcceleratorDesign/MAD-X/issues/93

In order to use the tool, you should first create a mapping of the revision
numbers to commit ids as follows:

.. code-block:: bash

    cd repo-clone
    git update-ref refs/notes/commits refs/svn/map
    git log --format="%H %s" --branches --tags \
        | cut -d':' -f1 | awk '{print $2 " " $1}' > revmap.txt

Now clone the tool from github:

.. code-block:: bash

    git clone git@github.com:mavam/trac-hub

You can use the script in ``tools/download-trac-attachments-mysql.sh`` as an
example of how to download attachments from the trac system and then e.g.
create a git repository containing all the attachments.

Next, create a config file that defines access to your trac database and your
github user / token:

.. code-block:: bash

    cd trac-hub
    cp config.yaml.example config.yaml

When you're done, execute as follows:

.. code-block:: bash

    bundle install --path vendor/bundle
    bundle exec trac-hub \
        -a BASE_URL_FOR_ATTACHMENTS \
        -c config.yaml -r ../revmap.txt -s 1 \
        -S

While importing, I recommend to temporarily limit repository interactions to
collaborators only in the repositories settings.
