public: yes
tags: [git, plumbing, history, rewrite, filter-branch, extract, unpack]
summary: |
  Writing an efficient tree filter for unpacking zipped files.

git unpack: efficient tree filter
=================================

I recently had the pleasure of migrating an SVN repository with about 6300
revisions and 370 tags/branches to git. One of the peculiarities with the
original repository was that they decided to *gzip* many of their large
(>100KiB) text files. The idea behind this was, I guess, to reduce checkout
and transfer sizes.

In git, of course, gzipping your files will in fact increase the overall size
of the repository! The reason is that you generally fetch the entire history
in git (not only the current work-tree as in SVN) and that gzipping prevents
git from packing similar objects efficiently (packfiles_).

Furthermore, gzipping text files isn't too nice because it doesn't play well
with diffs and some text-processing tools (yes, git can be configured to diff
with zcat, but this has to be done by every user…). Clearly, I should get rid
of these files before publishing your new git repository – but how?

.. contents:: :local:

.. _packfiles: http://alblue.bandlem.com/2011/09/git-tip-of-week-objects-and-packfiles.html

git filter-branch
~~~~~~~~~~~~~~~~~

No problem, I thought, let's just ``git filter-branch`` these files to hell:

.. code-block:: bash

    CWD="$(pwd)" git filter-branch \
        --index-filter '$CWD/extract_gz_files.sh' \
        -- --branches --tags

With the following script in the current directory:

.. code-block:: bash
    :caption: extract_gz_files.sh

    #! /bin/zsh
    mkdir -p .known-objects

    git ls-tree -lr $GIT_COMMIT | while read -r MODE TYPE OBJ SIZE NAME; do
        if [[ $NAME == *.gz ]]; then
            if [[ ! -e .known-objects/$OBJ ]]; then
                git cat-file blob $OBJ |
                    gunzip |
                    git hash-object -w -t blob --stdin > .known-objects/$OBJ
            fi
            OBJ=$(< .known-objects/$OBJ)
            git update-index --remove $NAME
            git update-index --add --cacheinfo $MODE,$OBJ,${NAME%.gz}
        fi
    done

This works fine. BUT:

Have you ever tried to use ``git filter-branch --index-filter`` on a large
repository? The above command needs about 2 hours (with 99% of the time spent
in only those 2000 commits where files actually had to be extracted).

Efficient rewrites
~~~~~~~~~~~~~~~~~~

Part of the reason that ``git filter-branch`` can be so slow, is that it is
fully sequential and takes no advantage of parallelization. While sequential
processing is required for the commits themselves, the rewriting of the trees
can be efficiently parallelized. The other main reason is that it is hard make
use of caching for already computed subtrees.

`Large scale Git history rewrites`_ is a great article which pushes this to
the extreme and shows a lot of tricks to speed up your performance. However,
his blink_history_rewrite_ module is perhaps too heavily optimized: it makes a
lot of assumptions about how the internal structure of the git object database
and does not make use of higher-level tools. For this reason, the code is very
fragile. And indeed: I could not get it to run even though I performed all the
listed preparation steps – maybe because I'm using a newer version of git, and
maybe because of something else entirely.

Nonetheless inspired by this article, I created a similar module that uses git
commands and makes no assumptions about the underlying storage model (whether
objects are stored in packfiles, etc).

Of course, my module is likely a factor 10 or more slower than his, but on the
other hand: you should be able to use this module with every git repository;
and without having to perform any preparation steps as described in the above
article (they may, however, still result in performance improvements).

Very first, clone your repository, you don't want to accidentally lose data:

.. code-block:: bash

    git clone ORIG DEST --mirror
    cd DEST

Okay, we're ready to rewrite. Instead of the single filter-branch command, we
proceed now in two phases.

First, rewrite the trees using the python module (parallelized). This creates
a folder ``objmap`` where it stores for each top level tree, the hash of the
tree with which it should be replaced:

.. code-block:: bash

    git clone https://github.com/coldfix/git-filter-tree

    git log --format='%T' --branches --tags | \
        python git-filter-tree/git_filter_tree unpack

And second, rewrite the commits using ``git filter-branch --commit-filter``,
making use of the ``objmap/`` folder created in phase 1 (still sequential, but
fast enough):

.. code-block:: bash

    git filter-branch --commit-filter '
        obj=$1; shift; git commit-tree $(cat $GIT_DIR/objmap/$obj) "$@"' \
        -- --branches --tags

Voilà, the 2 hour job is now done in 4 minutes, factor 30 speedup, not bad.

.. _Large scale Git history rewrites: https://www.bitleaks.net/blog/large-scale-git-history-rewrites/
.. _blink_history_rewrite: https://github.com/primiano/git-tools/tree/master/history-rewrite

Remove unneeded objects
~~~~~~~~~~~~~~~~~~~~~~~

After you're finished with either ``filter-branch`` command, you may find that
the repository still takes up more space than than the original repository. So
all of that for nothing? No, it's just that we haven't performed a final step:

We have to to tell git to clean up, delete all the unreferenced objects and
compress all the others. Be sure to do this only on your cloned repository –
otherwise you will lose data:

.. code-block:: bash

    rm -rf refs/original/
    git reflog expire --expire=now --all
    git gc --prune=now
    git gc --aggressive --prune=now

Give me a one-liner!
~~~~~~~~~~~~~~~~~~~~

Sorry, two lines:

.. code-block:: bash

    git clone https://github.com/coldfix/git-tree-filter

    ./git-tree-filter/git-unpack ORIG DEST

While my particular use-case may be rather rare, the pattern is genuinely
generic. So, if you're interested to do a similar but different tree-rewrite,
and you don't mind writing a few lines of python code, you may be able to
adapt the unpack_ module for your own purposes.

Also, please don't hesitate to open issues and/or submit pull-requests with
more examples.

.. _unpack: https://github.com/coldfix/git-filter-tree/blob/master/git_filter_tree/unpack.py
