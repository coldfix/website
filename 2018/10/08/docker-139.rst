public: yes
tags: [docker, config, error]
summary: |
  when most containers error with 139

docker - error 139
==================

If you are running archlinux like me or any other distribution with a modern
kernel (≥ 4.15.0-1), and most or all of your docker containers error with
error 139 on startup, it might be due to *vsyscalls* being disabled by
default. This can be reenabled by adding the ``vsyscalls=emulate`` `kernel
parameter`_.

Note that 139 signifies a segmentation fault which is a very general runtime
error. So if just one container errors, it's probably a bug in the running
software, if many or most containers do, there is probably a deeper underlying
problem.

.. _kernel parameter: https://wiki.archlinux.org/index.php/Kernel_parameters
