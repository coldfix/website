public: yes
tags: [git, plumbing, history]
summary: |
  Asking history questions

git du: historic object size
============================

Ever wanted to do ``git du``, accumulating the size of folders or files
through the entire history? Or just wanted to know the maximum or average size
of a file or folder?

You might find the following example useful to adapt for your needs:

.. code-block:: bash

    git rev-list master |
        xargs -l1 -- git ls-tree -lr |
        ./git-du-helper.pl \
    > raw_sizes.txt

This assumes you have downloaded the git-du-helper.pl_ script into your
current working directory.


What's going on here?

- ``git rev-list master`` prints all revisions in the history of ``master``
- ``| xargs -l1 -- git ls-tree -lr`` shows a listing of files + size for each
  revision
- ``| ./git-du-helper.pl`` analyzes the text data (no interaction with git).
- ``-f`` means that only files should be printed, not directories
- ``> raw_sizes.txt`` write the output to a tabular file with columns
  ``SUM_SIZE MAX_SIZE NUM_REVS PATH``.

You can now pose additional queries to get pretty-printed output, e.g. sort by
``MAX_SIZE``, show human readable sizes (KiB/MiB/…) and columnate:

.. code-block:: bash

    < raw_sizes \
        sort -n -k2,2  |
        numfmt --to=iec-i --field=1,2 --format='%.1f ' --suffix=B |
        column -t > file_sizes.txt

Note that these commands don't reflect the actual storage size on disk because
git compresses objects and can pack similar objects based on deltas using
packfiles_ (see also this `excellent answer on SO`_ and maybe `this post`_).
If you want to detect large files on disk, take a look at Steve Lorek's
article `How to Shrink a Git Repository`_ which shows how to get actual file
sizes using ``git verify-pack``.

.. _git-du-helper.pl: ../git-du-helper.pl
.. _packfiles: http://alblue.bandlem.com/2011/09/git-tip-of-week-objects-and-packfiles.html
.. _excellent answer on SO: https://stackoverflow.com/a/5576688/650222
.. _this post: https://codewords.recurse.com/issues/three/unpacking-git-packfiles/
.. _How to Shrink a Git Repository: http://stevelorek.com/how-to-shrink-a-git-repository.html


For completeness, my git-du-helper.pl_ looks as follows:

.. code-block:: perl
    :caption: git-du-helper.pl

    #! /usr/bin/env perl

    use strict;
    use warnings;

    use File::Basename qw(dirname);
    use List::Util qw(sum max);

    my $just_files = scalar(@ARGV) > 0 && $ARGV[0] eq '-f';
    my %folder_contents;

    while (<>) {
        chomp;
        my ($mode, $kind, $hash, $size, $filename) = split(/\s+/, $_, 5);
        do {
            $folder_contents{$filename}{$hash} = $size
        } until ($just_files || (($filename = dirname($filename) . "/") eq './'));
    }

    while (my ($path, $objects) = each %folder_contents) {
        print(sum(values %$objects), " ",
              max(values %$objects), " ",
              scalar(keys %$objects), " ",
              $path, "\n");
    }
