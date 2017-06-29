public: yes
tags: [dovecot, postfix, mail, server, linux, config, gist]
summary: |
  Configure postfix + dovecot for your own single account webserver

Being your own Postmaster
=========================

.. TODO lexers main.cf, dovecot.conf?

.. contents:: :local:
    :depth: 1

**EDIT 29.06.2017:** *Please set dovecot's ``ssl_cert`` to ``fullchain.pem`` to
make thunderbird stop complaining!*

Objective
~~~~~~~~~

My objective is to setup a mail service on my personal web server for
preliminarily only one user: me. For now, there should be only one mailbox
that receives all mail addressed to any email address under my domain.
However, the config must be flexible enough to easily allow adding additional
accounts for distinct purposes or accounts for friends – without touching the
actual config files.  As this is a remote mail service, linux users and
mailbox accounts should be entirely distinct:

- Mailbox users should not automatically have access to system user accounts!
- Not every system user should have a corresponding mailbox! (Not every system
  user corresponds to addressable entity, or a *unique* one at that.)
- Persons should have the possibility to have multiple mailboxes easily.

To make it short the setup that I want can be characterized as follows:

- statically configured account(s)
- catch-all account
- IMAP/POP3/SMTP services
- SSL encryption
- *virtual* user accounts!
- LMTP for communication with dovecot
- no SQL
- simplicity!

Missing features (for now):

- webinterface
- spam filter

I will assume you already have a valid SSL certificate (e.g. using
letsencrypt_) and your MX domain records set up correctly.

.. _letsencrypt: https://letsencrypt.org/

Bird's eye
~~~~~~~~~~

.. image:: ../postfix-dovecot.svg

postfix is responsible for:

- receive incoming mail from the internet
- receive new mail from the user
- decide what to do with accepted mail
- deliver incoming mail to dovecot
- send outgoing mail to the internet

dovecot is responsible for

- handle user authentication
- manage account mailbox
- provide IMAP/POP3 server

Yet another...?
~~~~~~~~~~~~~~~

There is a ton of guides out there on how to setup a mailserver using postfix
and dovecot, so do I write yet another one?

Truth is many of those guides didn't do too much explaining of the workings
behind the shown configuration and so I was still on my own when trying to
implement a variant according to my needs.

I will try to explain the things as I understood them and I hope to give some
rationale why I did what I did. More importantly, I will point out where I
lack deep understanding of the issue and which parts need more consideration –
so you don't blindly follow and copy-paste my config in the hope that I know
something you don't. This is something I missed very much in other guides.

I am no expert, so you should take everything I tell with a (huge) grain of
salt!

postfix config
~~~~~~~~~~~~~~

The postfix MTA (mail transfer agent) receives mail from internet or local
clients and delivers it locally to a mailbox program or forwards it to the
internet.

After installing postfix, we will setup a new config from scratch. Backup the
old config first:

.. code-block:: bash

    cp /etc/postfix/main.cf{,.bak}
    cp /etc/postfix/master.cf{,.bak}

The first file (``main.cf``) contains the config, while ``master.cf``
describes which additional services to run.

.. contents:: :local:
    :depth: 1

main.cf
-------

When writing the config file, it is important look up descriptions for the
individual parameters in the `postconf man page`_ (``man 5 postconf``) for
more details on the parameters and query default values with ``postconf -d``.
These may change between versions.

.. _postconf man page: http://www.postfix.org/postconf.5.html

General settings
````````````````

We start with some general settings, nothing too exciting for now.

.. code-block:: ini
    :caption: /etc/postfix/main.cf

    # Make localhost the only trusted host:
    mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128

    # Internet hostname of this machine:
    myhostname = coldfix.de
    myorigin = $myhostname
    mydomain = $myhostname

    # Misc settings (most of this blindly copied from the internet):
    biff = no
    append_dot_mydomain = no
    readme_directory = no
    mailbox_size_limit = 0
    recipient_delimiter = +
    # default is a bit low (9 MiB), let's allow 128 MiB
    message_size_limit = 134217728

Now, let's get to the more setup-specific parts.

SASL (user authentication)
``````````````````````````

The following instructs postfix to communicate to dovecot for querying user
authentication when someone tries to send a mail via SMTP:

.. code-block:: ini
    :caption: /etc/postfix/main.cf

    # Authenticate SMTP logins by dovecot through a unix-domain-socket:
    smtpd_sasl_type = dovecot
    smtpd_sasl_path = private/auth
    smtpd_sasl_auth_enable = yes
    smtpd_sasl_local_domain = $myorigin

Mail delivery
`````````````

Now, we start setting up routing for accepted email.

First, define which domains should be handled as *local*. Incoming emails for
these addresses will not be forwarded to dovecot. Therefore: do not put your
domain here if you want to let dovecot handle addresses in its address space.

.. code-block:: ini
    :caption: /etc/postfix/main.cf

    # Hosts for local-relay (i.e. non-virtual):
    mydestination = localhost, localhost.localdomain
    alias_maps = hash:/etc/aliases
    alias_database = hash:/etc/aliases

The file ``/etc/aliases`` contains a mapping of aliases for local users. It
will be shown below.

I think of local addresses as email addresses corresponding to system users (I
could be wrong!), and therefore prefer the more powerful *virtual* users. This
specifies for which addresses incoming emails should be handed off to dovecot.

.. code-block:: ini
    :caption: /etc/postfix/main.cf

    # Hosts for virtual relay:
    virtual_mailbox_domains = coldfix.de, coldfix.eu
    # The alias map implements a catch-all user:
    virtual_alias_maps      = hash:/etc/postfix/virtual
    # Deliver mails to dovecot on a unix-domain-socket:
    virtual_transport       = lmtp:unix:private/dovecot-lmtp

This is not the complete story, however. You can also deliver *local* mail to
dovecot by using ``mailbox_transport`` in addition to or instead of
``virtual_transport`` (but same value). I can't tell you about the precise
differences between both approaches, though.

Again, I will show ``/etc/postfix/virtual`` down below. It defines aliases for
virtual users and can be used to implement a catch-all rule.

SMTP
````

Now, we take care of configuring postfix's SMTP server and the SSL encryption.
I consider anything before TLSv1.2 obsolete.

.. code-block:: ini
    :caption: /etc/postfix/main.cf

    # SMTP SSL/TLS certificates
    smtpd_banner = $myhostname ESMTP $mail_name
    smtpd_use_tls = yes
    smtpd_tls_cert_file = /etc/letsencrypt/live/$myhostname/fullchain.pem
    smtpd_tls_key_file  = /etc/letsencrypt/live/$myhostname/privkey.pem
    smtpd_tls_auth_only = yes
    smtpd_tls_security_level = may
    smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
    smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
    smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache
    smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache
    smtp_tls_security_level = may

Please take into account that this SSL config is probably incomplete and you
should definitely not blindly copy-paste! Remaining issues include:

- should restrict list of used ciphers
- using opportunistic (``level=may``) rather than mandatory (``encrypt``) TLS.
  Apparently, *publicly-referenced* SMTP servers that use this setting will
  not be `RFC 2487`_-conformant. Not sure what this means for our case, but I
  had problems with ``level=encrypt`` at some point, so I changed back.

.. _RFC 2487: https://tools.ietf.org/html/rfc2487

Now, we define some rules for the SMTP server. Note, that I do not understand
them in detail and you should *absolutely* improve them for your own
configuration. In particular, these contain **no restriction on username** a
user can send emails with – as long as the email address belongs to an owned
domain. This is intentional for my use case (single admin user), but likely
undesirable in most other cases.

.. code-block:: ini
    :caption: /etc/postfix/main.cf

    # SMTP Restrictions
    smtpd_helo_required = yes
    smtpd_helo_restrictions = reject_invalid_helo_hostname
    smtpd_sender_restrictions = reject_unknown_sender_domain
    smtpd_recipient_restrictions = permit_mynetworks,
                                   permit_sasl_authenticated,
                                   reject_unknown_recipient_domain,
                                   reject_unauth_pipelining,
                                   reject_unauth_destination

.. TODO read up, improve!

That's it for the ``main.cf`` file.

master.cf
---------

The ``/etc/postfix/master.cf`` file specifies which services postfix should
run. To run SMTP for letting users send new mail, uncomment the following
line:

.. code-block:: txt
    :caption: /etc/postfix/master.cf

    submission inet n       -       -       -       -       smtpd

I'm not sure about the corresponding options in the following lines. I will
have to read up before I can say for certain, but I believe that these take as
defaults the values specified in ``main.cf``, so you don't need to define them
here, if you did properly take care of that in the main config file.

.. TODO read up, improve!

aliases
-------

Most importantly, we have to define virtual aliases. I use these to setup a
catch-all rule:

.. code-block:: txt
    :caption: /etc/postfix/virtual

    @coldfix.de thomas
    @coldfix.eu thomas

Which will forward all emails addressed to any email under the respective
domains to either *thomas@coldfix.de* or *thomas@coldfix.eu*.

Postfix wants a precompiled database version of this file, which we can
generate as follows:

.. code-block:: bash

    postmap /etc/postfix/virtual

Now, we define aliases for *local users* in the ``/etc/aliases`` file. This
probably doesn't matter anyway, because we have setup postfix such that the
aliases will only be used for mails addressed in the form ``user@localhost``
which should usually not happen. But still, I want to get notified if anything
unexpected happens, and so I made a small modification to the default file
provided by debian. Essentially, only the last two lines are added,
effectively forwarding mail to the virtual address space:

.. TODO leave out this part?

.. code-block:: txt
    :caption: /etc/aliases
    :emphasize-lines: 13,14

    mailer-daemon: postmaster
    postmaster: root
    nobody: root
    hostmaster: root
    usenet: root
    news: root
    webmaster: root
    www: root
    ftp: root
    abuse: root
    noc: root
    security: root
    root: thomas
    thomas: thomas@coldfix.de

And generate a binary database:

.. code-block:: bash

    postalias /etc/aliases

Let it sink in
--------------

After any modifications, we regenerate binary alias databases and restart
postfix to let the changes take effect:

.. code-block:: bash

    postmap /etc/postfix/virtual
    postalias /etc/aliases
    systemctl restart postfix


dovecot config
~~~~~~~~~~~~~~

For a small config like ours, I recommend not going with the config file
clutter as laid out by the debian package, but rather keep everything in a
single compact file. This reduces the required headspace by square miles
(assuming your brain is 2D). Note that you can use ``dovecot -n`` to get a
compact listing of your current config. To exchange a cluttered config with a
single file, you can do, e.g.:

.. code-block:: bash

    cd /etc/dovecot
    dovecot -n > dovecot.conf.new
    cp dovecot.conf{,.bak}
    cp dovecot.conf{.new,}

I used this as a starting point for the following.

Some general settings:

.. code-block:: kconfig
    :caption: /etc/dovecot/dovecot.conf

    # Setup logging:
    log_path = /var/log/dovecot.log
    info_log_path = /var/log/dovecot-info.log

    # Supported protocols:
    protocols = imap pop3 lmtp

Now, start secure IMAP and POP3 servers:

.. code-block:: kconfig
    :caption: /etc/dovecot/dovecot.conf

    # IMAP/POP servers:
    ssl = required
    ssl_cert = </etc/letsencrypt/live/coldfix.de/fullchain.pem
    ssl_key = </etc/letsencrypt/live/coldfix.de/privkey.pem
    ssl_protocols = !SSLv2 !SSLv3 !TLSv1 !TLSv1.1

    service imap-login {
      inet_listener imaps {
        port = 993
        ssl = yes
      }
    }

    service pop3-login {
      inet_listener pop3s {
        port = 995
        ssl = yes
      }
    }

Define interface on which to receive mails from postfix:

.. code-block:: kconfig
    :caption: /etc/dovecot/dovecot.conf

    # Listening for incoming messages from postfix:
    service lmtp {
      unix_listener /var/spool/postfix/private/dovecot-lmtp {
        group = postfix
        mode = 0600
        user = postfix
      }
    }

Define interface on which to offer authentication services for postfix's SMTP:

.. code-block:: kconfig
    :caption: /etc/dovecot/dovecot.conf

    # SASL authentication for postfix's SMTP:
    service auth {
      unix_listener /var/spool/postfix/private/auth {
        group = postfix
        mode = 0666
        user = postfix
      }
    }

Now, we come to a part that calls for a little more explanation, because you
will most likely have to tweak according to your own needs: user lookup and
authentication. But don't worry – we are almost through!

The ``userdb {...}`` dict tells dovecot how to locate mailbox accounts, where to
store their mail and can configure further account-specific settings.

Recall that my goal is a server with only a few accounts, who I want to
configure manually. These should be truly virtual and not have anything to do
with system users. Therefore, the simplest option for me is the *static*
driver defines a common pattern to be used for all accounts, but cannot check
for account existence before authentication:

.. code-block:: kconfig
    :caption: /etc/dovecot/dovecot.conf

    # Default mailbox dir, relative to account's $home:
    mail_location = maildir:~

    userdb {
      driver = static
      args = uid=vmail gid=vmail home=/var/vmail/%n
    }

This instructs dovecot to set ``/var/vmail/USERNAME`` as the home folder for
the account, and then store mails directly into that folder. Note, that I'm
using ``%n`` rather than ``%u`` or ``%d/%n`` on purpose: By not including
domain information in the path, users for two different domains (*.de*, *.eu*)
will be equivalent. The data will be accessed under the system user and group
``vmail:vmail`` which you can create as follows:

.. code-block:: bash

    groupadd -g 5000 vmail
    useradd -m -d /var/vmail -s /bin/false -u 5000 -g vmail vmail

If you need more fine-grained control over user-specific settings, consider
using ``driver = passwd-file``, which allows to specify system user, group,
home folder and further settings on a per-account basis and can share the same
file as the one used for password-lookup. See also the passwd-file_ format.

.. _passwd-file: http://wiki2.dovecot.org/AuthDatabase/PasswdFile

Password-lookup is specified by ``passdb`` dict:

.. code-block:: kconfig
    :caption: /etc/dovecot/dovecot.conf

    passdb {
      driver = passwd-file
      args = username_format=%n /etc/dovecot/users
    }

Again, using ``%n`` means sharing the same entries for different domains.

Passwords for the user accounts are put in the file ``/etc/dovecot/users``.
which should look like this:

.. code-block:: txt
    :caption:  /etc/dovecot/users

    thomas:{PLAIN}mypassword

More generally, the file format is described by the passwd-file_ format.

I don't know about the following, it might or might not be necessary, but it
was part of what I got from ``dovecot -n`` and it looked reasonable:

.. code-block:: kconfig
    :caption: /etc/dovecot/dovecot.conf

    namespace inbox {
      inbox = yes
      location =
      mailbox Drafts {
        special_use = \Drafts
      }
      mailbox Junk {
        special_use = \Junk
      }
      mailbox Sent {
        special_use = \Sent
      }
      mailbox Trash {
        special_use = \Trash
      }
      prefix =
    }


That should be it!

Restart dovecot:

.. code-block:: bash

    systemctl restart dovecot

And hope for the best!

