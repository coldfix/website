tags: [coding, python]
summary: |
  Using the current remote HEAD

Update all Git submodules
=========================

The problem
~~~~~~~~~~~

Consider you have a repository with several submodules (e.g. configuration or
programs with plugins, or a parent project that is used to bundle the parts of
a modular software such as Qt). From time to time you may want to pull in all
the newest upstream versions of all submodules. Doing this manually (``cd
submodule; git pull; cd ..``) can become tiresome very quickly, which is why
you could use ``git submodule foreach`` to avoid some of these repetitions:

.. code-block:: bash

    git submodule foreach \
        git pull

This has a tendency to fail because submodules are only tracked by commit not
by branch and will therefore go into detached HEAD mode if you ever use ``git
submodule update`` to checkout their current versions as defined by the parent
repository. In this case there is simply no active branch that could be
pulled. Consequentyl, the ``git pull`` fails for the respective submodule,
and, the loop stops executing at the first error, leaving you with the
responsibility to checkout the correct branch beforehand.  Again, we could try
``git submodule foreach`` for that:

.. code-block:: bash

    git submodule foreach \
        'git checkout master && git pull'

But this may fail too because the remote branch may be named differently,
especially with the increasing number of projects migrating to the convention
of using a ``main`` branch.

If you don't care about losing local changes, you could go for
``fetch``/``reset``:

.. code-block:: bash

    git submodule foreach \
        'git fetch && reset --hard origin/HEAD'

But this is dangerous for people who sometimes modify the submodules.

So, what we ideally want is a command that:

- updates a repository to the newest version of the remote HEAD branch
- works independently of the remote HEAD branch name
- works in detached HEAD mode
- doesn't overwrite local modifications


The easy way
~~~~~~~~~~~~

The simplest solution that almost always works is to avoid the branch name
dilemma by pulling directly from ``origin/HEAD``:

.. code-block:: bash

    git submodule foreach \
        git pull origin HEAD --ff-only

This will usually do the right thing -- unless you checked out a different
branch, or someone force-pushed to the remote. The ``--ff-only`` option is
used to prevent git from creating a merge commit in these situations (unless
that's what you want, in that case simply leave it out).

I'm not aware of any straightforward command that handles these cases as well,
but please let me know if there is a better option.


The hard way
~~~~~~~~~~~~

For completeness, let me also show you how to checkout the remote HEAD branch.
This is helpful in the case where you may have checked out local branches in
each submodule and want to switch all of them back to the main branch.

We will define two helper commands for that. Both can either be defined as
aliases or put as scripts in your PATH.

git main
--------

The purpose of this subcommand will simply be to retrieve the name of the
remote main branch. It has one optional argument ``git main [remote]``
defaulting to *origin*. It works by checking where ``origin/HEAD`` points to
in the output of ``git branch -a``:

.. code-block:: bash

    #! /usr/bin/env bash
    main() {
        local origin=${1-origin}
        local escaped=$(sed -e 's/:[]\/$*.^[]/\\&/g' <<<"$origin")
        git branch -a | \
        sed -n "s:^\s*remotes/$escaped/HEAD -> $escaped/\(.*\)$:\1:p"
    }
    main "$@"

In order to make it available as git command, you can `download it
<./git-main>`_ it, save it as ``~/.local/bin/git-main`` and make it executable
(also make sure that folder is actually in your PATH).

Alternatively, put the following version in your ``~/.gitconfig``
file and be careful to keep all the weird escaping:

.. code-block:: ini

    [alias]
    main = "!f() { \
        local origin=${1-origin}; \
        local escaped=$(sed -e 's/:[]\\/$*.^[]/\\\\&/g' <<<\"$origin\"); \
        git branch -a | \
        sed -n \"s:^\\s*remotes/$escaped/HEAD -> $escaped/\\(.*\\)$:\\1:p\"; \
    }; f"


git update-head
---------------

There is another (rare) case, that can cause avoidable problems: If the name
of the remote HEAD branch has changed after you had cloned it, the ``git
branch -a`` command will not be able to see the new ``HEAD -> branchname``
mapping (for some reason ``git fetch`` doesn't seem to fetch this information
as of git v2.34).

For more information on the topic, see `How does origin/HEAD get set?`_. It
was really helpful for creating the following ``git update-remote-head
[remote]`` subcommand that updates local knowledge of the remote HEAD branch
name:

.. code-block:: bash

    #! /usr/bin/env bash
    remote-update-head() {
        local origin=${1-origin}
        git remote set-head "$origin" "$(
            git remote show "$origin" |
            sed -n 's/^\s*HEAD branch: \(.*\)$/\1/p'
        )"
    }
    remote-update-head "$@"

Again, you can `download it here <./git-remote-update-head>`_, make it
executable, save it as ``~/.local/bin/git-update-head``, make it executable,
and make sure that folder is in your PATH.

Alternatively, put the following alias in your ``~/.gitconfig``:

.. code-block:: ini

    [alias]
    remote-update-head = "!f() { \
        local origin=${1-origin}; \
        git remote set-head \"$origin\" \"$( \
            git remote show \"$origin\" | \
            sed -n 's/^\\s*HEAD branch: \\(.*\\)$/\\1/p' \
        )\"; \
    }; f"

.. _How does origin/HEAD get set?: https://newbedev.com/how-does-origin-head-get-set


Putting it all together
-----------------------

With this machinery, you can now checkout and pull the main branch as
follows:

.. code-block:: bash

    git submodule foreach \
        'git checkout $(git main) && git pull origin HEAD'

If you suspect remote HEAD branches may have changed (rarely the case),
execute this beforehand:

.. code-block:: bash

    git submodule foreach \
        git remote-update-head
