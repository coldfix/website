public: no
tags: [config, tex, zsh, util, helper, gist]
summary: |
  When you can't use texdoc…

ad-hoc texdoc
=============

Archlinux does not include documentation for tex packages. Therefore, native
``texdoc`` does not work:

.. code-block:: zsh

    % texdoc siunitx 
    Sorry, no documentation found for siunitx.
    If you are unsure about the name, try searching CTAN's TeX catalogue at
    http://ctan.org/search.html#byDescription.

Consider using this (very primitive) replacement for texdoc:

.. code-block:: zsh
    :caption: ~/.zshrc

    #! /bin/zsh

    function texdoc
    {
        prefix=$HOME/.texdoc
        pkg=$1
        doc=$(hrefbytext http://ctan.org/pkg/$pkg 'Pack­age doc­u­men­ta­tion') &&
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
        hrefbytext "http://ctan.org/pkg/subcaption" "Pack­age doc­u­men­ta­tion"
    """

    import sys
    from lxml.html import parse


    def main(args):
        url = args[0]
        doc = parse(url).getroot()
        text = args[1]
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
