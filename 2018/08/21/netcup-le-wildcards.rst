tags: [server, config, ssl, letsencrypt]
summary: |
  How to issue Let's Encrypt wildcard certificates for netcup

Let's Encrypt wildcard certificates
===================================

`Earlier this year`_, `Let's Encrypt`_ gained the ability to issue `wildcard
certificates`_ (``*.domain.tld``). I was anticipating this eagerly, as this
removes the need to manually list my 92 subdomains and update the certificate
every time a new subdomain is added.

The protocol used to issue wildcard certificates requires the user to proof its
control over the domain by setting a `TXT record`_ on their DNS server.
certbot_, the EFF's official client, has several DNS authenticator plugins that
facilitate this task for major DNS provider APIs. However, there was at first
no such plugin for my webhosting provider, netcup_, so I went and manually_
added the TXT records in the web interface the first time.

.. _Earlier this year: https://community.letsencrypt.org/t/acme-v2-and-wildcard-certificate-support-is-live/55579
.. _Let's Encrypt: https://letsencrypt.org/
.. _wildcard certificates: https://en.wikipedia.org/wiki/Wildcard_certificate
.. _TXT record: https://en.wikipedia.org/wiki/TXT_record
.. _certbot: https://certbot.eff.org/
.. _netcup: https://www.netcup.eu/
.. _manually: https://blog.effenberger.org/2018/03/19/wildcard-certificates-with-lets-encrypt/


netcup DNS authenticator
------------------------

When the expiry date approached, I decided it was finally time for automation.
Much to my delight, I discovered that netcup had just recently released a `DNS
API`_, and that there was already a python wrapper called nc_dnsapi_ on PyPI.
With these tools writing a certbot plugin became a breeze, and I was able to
release the first version of the `certbot-dns-netcup`_ plugin on PyPI the next
day.

.. _DNS API: https://www.netcup-wiki.de/wiki/DNS_API
.. _nc_dnsapi: https://pypi.org/project/nc-dnsapi/
.. _certbot-dns-netcup: https://pypi.org/project/certbot-dns-netcup/

In order to use it, you have to install it into the same environment as
certbot itself. Note that if you're using certbot-auto, `you're going to have
a hard time`_. Personally, I use docker, as shown below. If you obtained
certbot via the system package manager, it is as simple as:

.. code-block:: bash

   pip install certbot-dns-netcup

Next, create a configuration file with your API credentials. These can be
created or found in the netcup CCP_. The configuration file should look like
this:

.. code-block:: ini
   :caption: netcup_credentials.ini

   certbot_dns_netcup:dns_netcup_customer_id  = 123456
   certbot_dns_netcup:dns_netcup_api_key      = 0123456789abcdef0123456789abcdef01234567
   certbot_dns_netcup:dns_netcup_api_password = abcdef0123456789abcdef01234567abcdef0123

Note that the ``certbot-dns-netcup:`` prefix is imposed by certbot for external
plugins. You will need to remove it from the config file and the command
options in case the plugin is ever merged into certbot upstream.

You can now instruct certbot to use the netcup authenticator by passing the
following options:

.. code-block:: bash

   certbot certonly \
      --authenticator certbot-dns-netcup:dns-netcup \
      --certbot-dns-netcup:dns-netcup-propagation-seconds 900 \
      --certbot-dns-netcup:dns-netcup-credentials \
          ~/.secrets/certbot/netcup.ini \
      --server https://acme-v02.api.letsencrypt.org/directory \
      -d 'example.com' -d '*.example.com'

It is necessary to set a relatively high waiting time, e.g.
``dns-netcup-propagation-seconds=900`` in order to give the DNS records time to
propagate.

.. _you're going to have a hard time: https://certbot.eff.org/docs/contributing.html#writing-your-own-plugin
.. _CCP: https://ccp.netcup.net/run/daten_aendern.php?sprung=api
.. _docker:


Docker
------

In order to obtain an image with the certbot and the dns-netcup plugin
installed, create a temporary directory and put the following ``Dockerfile``
within it:

.. code-block:: docker
   :caption: Dockerfile

   FROM certbot/certbot
   RUN pip install certbot-dns-netcup

Now, create the image as follows:

.. code-block:: bash

   docker built -t certbot/dns-netcup .

You can now run certbot using docker, e.g. assuming you have put your
``netcup_credentials.ini`` file to ``/var/lib/letsencrypt``:

.. code-block:: bash

   docker run --rm \
      -v /var/lib/letsencrypt:/var/lib/letsencrypt \
      -v /etc/letsencrypt:/etc/letsencrypt \
      --cap-drop=all \
      certbot/dns-netcup certonly \
      --authenticator certbot-dns-netcup:dns-netcup \
      --certbot-dns-netcup:dns-netcup-propagation-seconds 900 \
      --certbot-dns-netcup:dns-netcup-credentials \
          /var/lib/letsencrypt/netcup_credentials.ini \
      --no-self-upgrade \
      --keep-until-expiring --non-interactive --expand \
      --server https://acme-v02.api.letsencrypt.org/directory \
      -d example.com -d '*.example.com'

For the other upstream DNS plugins, there are ready-to-use docker images online
that can be used likewise by simply replacing ``certbot/dns-netcup`` by the
image of choice, e.g. ``certbot/dns-cloudflare`` and using the appropriate
plugin specific options.


cronjob
-------

To put the cherry on the cake, you should add a cronjob that updates the
certificate periodically once you verified the script to be working. `My own
setup`_ uses a script that looks similar to this:

.. code-block:: bash
    :caption: cert-renew.sh

    #! /usr/bin/env bash
    here=$(readlink -f $(dirname "$BASH_SOURCE"))

    email=admin@coldfix.de
    domains=( 'coldfix.de' '*.coldfix.de' )

    # slightly randomize time when the cronjob is run:
    if [[ $1 = "--wait" ]]; then
        sleep $(expr $RANDOM % $2)m
        shift 2
    fi

    docker run --rm \
        -v "$here/var/letsencrypt":/var/lib/letsencrypt \
        -v /etc/letsencrypt:/etc/letsencrypt \
        --cap-drop=all \
        certbot/dns-netcup certonly \
            --authenticator certbot-dns-netcup:dns-netcup \
            --certbot-dns-netcup:dns-netcup-credentials /var/lib/letsencrypt/netcup_credentials.ini \
            --certbot-dns-netcup:dns-netcup-propagation-seconds 900 \
            --no-self-upgrade \
            --keep-until-expiring --non-interactive --expand \
            --server https://acme-v02.api.letsencrypt.org/directory \
            --email "$email" --text --agree-tos \
            --renew-hook 'touch /var/lib/letsencrypt/.updated' \
            ${domains[@]/#/-d } "$@"

    # Perform post-renewal actions (optional):
    if rm "$here/var/letsencrypt/.updated" 2>/dev/null &&
          -f "$here/cert-reload.sh"; then
        exec "$here/cert-reload.sh"
    fi

If the certificate was renewed, this runs a script ``cert-reload.sh`` that you
can put in the same directory to e.g. restart webservers etc.:

.. code-block:: bash
   :caption: cert-reload.sh

   systemctl reload nginx
   systemctl reload postfix
   systemctl restart dovecot

Now simply type ``crontab -e`` and add a line as follows:

.. code-block:: crontab

   0       1,13    *       *       *       /path/to/cert-renew.sh --wait 60 --quiet

.. _My own setup: https://github.com/coldfix/server
