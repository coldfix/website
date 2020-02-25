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
        prefix=$HOME/.cache/texdoc
        url=http://texdoc.net/pkg/$1
        mkdir -p $prefix
        cache=$prefix/$(basename $url) && (
        if [[ ! -e $cache ]]; then
            wget $url -O $cache
        fi
        ) &&
        evince $cache
    }

It will download documentation from CTAN and save it in ``~/.cache/texdoc/``
folder for future use.
