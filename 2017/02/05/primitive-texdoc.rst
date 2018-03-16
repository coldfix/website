public: yes
tags: [config, tex, zsh, util, helper, gist]
summary: |
  When you can't use texdoc…

ad-hoc texdoc
=============

Archlinux does not include documentation for tex packages. Therefore, native
``texdoc`` does not work:

.. code-block:: txt
    :emphasize-lines: 1

    % texdoc siunitx
    Sorry, no documentation found for siunitx.
    If you are unsure about the name, try searching CTAN's TeX catalogue at
    http://ctan.org/search.html#byDescription.

Consider using this (very primitive) replacement for texdoc:

.. code-block:: bash
    :caption: ~/.zshrc

    function texdoc
    {
        prefix=$HOME/.texdoc
        pkg=$1
        doc=$(hrefbytext http://ctan.org/pkg/$pkg
                         'Pack&shy;age doc&shy;u&shy;men&shy;ta&shy;tion') &&
        mkdir -p $prefix
        cache=$prefix/$(basename $doc) && (
        if [[ ! -e $cache ]]; then
            wget $doc -O $cache
        fi
        ) &&
        evince $cache
    }

It will download documentation from CTAN and save it in your ``~/.texdoc/``
folder for future use.

The function has one more dependency, download this simple `utility script`_
and make it executable:

.. _utility script: ../hrefbytext

.. code-block:: python
    :caption: /usr/local/bin/hrefbytext

    #! /usr/bin/env python
    # encoding: utf-8

    """
    Get link by text content.

    Usage:
        hrefbytext URL TEXT

    Example:
        hrefbytext "http://ctan.org/pkg/subcaption" \
                   "Pack&shy;age doc&shy;u&shy;men&shy;ta&shy;tion"
    """

    import sys
    from urllib.request import urlopen
    from lxml.html import parse, fromstring


    def main(args):
        url = args[0]
        doc = parse(urlopen(url)).getroot()
        text = fromstring(args[1]).text_content()   # replace HTML entities
        for link in doc.cssselect('a'):
            if link.text_content() == text:
                print(link.get('href'))


    if __name__ == '__main__':
        main(sys.argv[1:])

In fact, I recommend saving it to ``~/bin/`` and adding that folder to your
PATH:

.. code-block:: zsh
    :caption: ~/.zshrc

    path=($path ~/bin)
