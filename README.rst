Varnish Cache Development Kit
=============================

This is VCDK, a project generator for Varnish modules or utilities. You can
use it to kick-start a module project, or a ``libvarnishapi`` consumer, or
both. It is written in shell and uses ``m4`` for code generation, it should
work on POSIX-compliant (or enough compliant) systems out of the box.

VCDK itself is just an empty shell (pun not intended) and code generation is
delegated to plug-ins. Once installed, the ``vcdk`` command is self-sufficient
to get started without a manual. It is currently of alpha quality, expect
rough edges and unimplemented features.

Quick tutorial
--------------

TODO

Installation
------------

For now, stripped down instructions::

    ./bootstrap
    make
    sudo make install

Contributing
------------

First, try using it on your system and please report any failure or error
message showing up. The code is supposed to be portable, it doesn't mean it
actually is.

Plug-in contributions are welcome, if you lack inspiration, think about other
build systems as alternatives to autotools (cmake or meson to name a few) and
try implementing one. It doesn't have to be a C project, there are bindings
available to other languages too, although not supported upstream.

If you can't do shell scripting, or can't make sense of the ad-hoc plug-in
system, a description of what a project would look like could help too.
