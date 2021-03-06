tags: [git, plumbing, history, rewrite, filter-branch, submodule, subtree]
summary: |
  How to (efficiently) turn a subdirectory into a git submodule.

git dir2mod: subdir to submodule
================================

Want to publish a git repository, but need to reduce the history size of the
main repository by changing one of its folders into a submodule – including
all branches and tags? This is a write up of the steps I took and at the end I
will link a script that can do the whole job.

.. contents:: :local:
    :depth: 1

Step by Step
------------

There are three basic steps:

.. contents:: :local:

Extract submodule
~~~~~~~~~~~~~~~~~

Our first step, `Splitting a subfolder out into a new repository`_ is a common
task and the standard method to do it works as follows (**don't skip to CLONE
or you will lose data!**):

.. code-block:: bash

    git clone <ORIGIN> <SUBMOD> --mirror
    cd <SUBMOD>
    git filter-branch --prune-empty --subdirectory-filter <FOLDER> \
        -- --branches --tags

And boom, you're done.

(Use ``--mirror`` to copy all your branches and tags and make a *bare*
repository!)

.. _Splitting a subfolder out into a new repository: https://help.github.com/articles/splitting-a-subfolder-out-into-a-new-repository/


**Remove untouched branches (optional)**

Assuming your branches and tags did form a connected graph before the rewrite,
you can remove the ones that did not contain the subdirectory in question as
follows:

.. code-block:: bash

    git show-ref | while read sha ref; do
        if ! git merge-base master $ref >/dev/null; then
            case $ref in
                refs/tags/*)  git tag    -d ${ref#refs/tags/}  ;;
                refs/heads/*) git branch -D ${ref#refs/heads/} ;;
            esac
        fi
    done

**Compress the new submodule (optional)**

Remove unused leftovers from your new repository:

.. code-block:: bash

    rm -rf refs/original/
    git reflog expire --expire=now --all
    git gc --prune=now
    git gc --aggressive --prune=now

Create index of submodule commits
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Next, we create an index that maps the SHA1 of the subdirectory tree to the
SHA1 of the associated commit in the submodule.

.. code-block:: bash

    git log --format="%T %H" --branches --tags > treemap

You should now have a file called ``treemap`` with the hashes of the
subdirectory tree and corresponding submodule commit.

Note, that this approach is only sensible if you never have the same tree
twice.

We are now done with the submodule, let's go back to the folder where both the
original repository and submodule are located:

.. code-block:: bash

    mv treemap ..
    cd ..

Rewrite the main repository
~~~~~~~~~~~~~~~~~~~~~~~~~~~

First off, clone your original repository! You don't want to lose data if
something goes wrong:

.. code-block:: bash

    git clone <ORIGIN> <PARENT> --mirror
    cd <PARENT>

Now, for simplicity ``export`` up pathes for later use:

.. code-block:: bash

    export submodule=...    # absolute path to the submodule
    export subfolder=...    # relative path of the subfolder inside the repo
    local  url=...          # url where the new submodule will be published

And create a file with the name ``gitmod`` in the directory of the clone with
the content that should be put in the ``.gitmodules`` file, e.g.:

.. code-block:: bash

    cat >gitmod <<EOF
    [submodule "$subfolder"]
        path = $subfolder
        url = $url
    EOF

(Note, the code below assumes that this file is located in the git directory,
so if you did not clone into a bare/mirror repo, you will have to move it to
``.git/`` or adjust the pathes accordingly.)

Before proceeding, we will also extract the ``treemap`` file into a directory
``treemap.dir`` that will be more convenient to access from a shell script:

.. code-block:: bash

    mkdir $submodule/treemap.dir
    while read tree sha1; do
        echo $sha1 > $submodule/treemap.dir/$tree
    done <$submodule/treemap

Finally, run ``filter-branch``:

.. code-block:: bash

    export NULL=$(git hash-object -w -t blob --stdin </dev/null)
    git filter-branch --index-filter '$GIT_DIR/dir2mod_helper.sh' \
        -- --branches --tags

With this itchy helper script in the git directory:

.. code-block:: bash
    :caption: $GIT_DIR/dir2mod_helper.sh

    #! /bin/sh
    mkdir -p .gitmod
    if obj_folder=$(git rev-parse $GIT_COMMIT:"$subfolder" 2>/dev/null); then
        obj_gitmod_old=$(git rev-parse $GIT_COMMIT:.gitmodules 2>/dev/null) ||
            obj_gitmod_old=$NULL
        obj_gitmod=$( cat .gitmod/$obj_gitmod_old 2>/dev/null ||
            (git cat-file blob $obj_gitmod_old && cat $GIT_DIR/gitmod) |
            git hash-object -w -t blob --stdin |
            tee .gitmod/$obj_gitmod_old )
        obj_submod=$(cat "$submodule"/treemap.dir/$obj_folder)
        git rm -r --cached --ignore-unmatch -q "$subfolder" .gitmodules
        git update-index --add --cacheinfo 100644,$obj_gitmod,.gitmodules
        git update-index --add --cacheinfo 160000,$obj_submod,"$subfolder"
    fi

Okay, this may look a bit monstrous but what it does is simply lookup the
correct commit ID for the tree that's currently at the subfolder's location
and replace the subfolder and the ``.gitmodules`` file accordingly.

For large repositories, this might be quite slow. If you don't want to wait
for hours, keep on reading:

Speed up the third step
-----------------------

As mentioned in `"git unpack: efficient tree filter"`_, tree filters can be
made a lot faster by parallelizing the tree rewrites and caching subtrees that
have already been computed.

Instead of the single filter-branch command, we now proceed in two phases.
First, use the python module to rewrite the trees (parallelized):

.. code-block:: bash

    git clone https://github.com/coldfix/git-filter-tree

    git log --format='%T' --branches --tags | \
        python git-filter-tree/git_filter_tree dir2mod \
        $(readlink -f ../treemap) $subfolder $url

This creates an index of ``OLD_TREE → NEW_TREE`` that associates to the root
tree of every existing commit its rewritten root tree. We will extract this
index into an easier to access directory structure:

.. code-block:: bash

    mkdir .git/trees
    <.git/objmap while read old new; do echo $new>.git/trees/$old; done

And second, rewrite the commits (sequential):

.. code-block:: bash

    git filter-branch --commit-filter '
        obj=$1; shift; git commit-tree $(cat $GIT_DIR/trees/$obj) "$@"' \
        -- --branches --tags

And a multi hour job can now be done in few minutes – there is still room for
performance improvements here. Feel free to submit questions and pull-requests
with your own adaptations on github.

.. _`"git unpack: efficient tree filter"`: ../../11/git-unpack


**Compress the new parent repository (optional)**

Be sure to do this only if you have cloned the original repository. Otherwise
you can lose data!

.. code-block:: bash

    rm -rf refs/original/
    git reflog expire --expire=now --all
    git gc --prune=now
    git gc --aggressive --prune=now


TL;DR: I want this done quickly
-------------------------------

I have assembled a script that performs all of these steps for you. Use it as
follows:

.. code-block:: bash

    git clone https://github.com/coldfix/git-tree-filter

    ./git-tree-filter/git-dir2mod \
        <ORIGIN> <SUBFOLDER> <SUBMODULE-URL> \
        <DEST-PARENT> <DEST-SUBMODULE>

With the following parameters:

.. code-block:: txt

    ORIGIN              Path or URL of the original repository.
    SUBFOLDER           Path of the subdirectory to extract.
    SUBMODULE-URL       URL where submodule will be published (for .gitmodules).
    DEST-PARENT         Path where the new "parent" repository will be created.
    DEST-SUBMODULE      Path where the new "child" repository will be created.
