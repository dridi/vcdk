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

Assuming that VCDK is already installed, let's start using it::

    $ vcdk
    vcdk: missing plugin argument

    Usage: vcdk [options] <plugin> [plugin options]
           vcdk --help
           vcdk --list

    Options can only appear once in the command line, and options that take
    an argument support both `--opt value` and `--opt=value` notations.
    When options accept list of arguments, they must be passed as a single
    comma-separated list of values, for example `--foo=bar,baz`.

    Options:
        --help               display this message and exit
        --list               list available plugins and exit
        --plugins=<dir>      default: /usr/libexec/vcdk

It complains, but provides basic usage information. Let's look at the plug-ins
to see what's available::

    $ vcdk --list
    autotools

OK, I guess not much of a choice, yet... Let's see what this plug-in has to
offer then::

    $ vcdk autotools
    vcdk: missing project name

    Usage: vcdk autotools [--vmod <vmod> [--vsc <vsc>]] [--vut <vut>] <name>
           vcdk autotools --help

    At least one VMOD or one VUT must be specified, a VSC can only be used
    in a VMOD. The name of the project must match this extended regular
    expression:

        ^[[:alnum:]][[:alnum:]_-]*$

    Options:
        --help               display this message and exit
        --output=<dir>       default: the project name
        --pkg=<list>         only 'rpm' is supported
        --scm=<scm>          only 'git' (default) is supported
        --verbose            display additional information
        --vmod=<list>        names of vmods to build
        --vsc=<list>         names of counters to build
        --vut=<list>         names of utilities to build

*This is not obvious yet, but only Varnish 6.x is supported, support for older
versions than the latest needs to be added one way or another, probably via
new plugins. As of the release of Varnish 6.2, the oldest supported series is
Varnish 6.0 LTS anyway.*

It complains again, but this time the usage information show  a bit more
capabilities (spoiler alert, not everything is implemented) so let's create a
project with two VMODs and two VUTs, with RPM packaging::

    $ vcdk autotools --pkg=rpm --vmod=foo,bar --vut=baz,qux tutorial

No output, let's try again::

    $ vcdk autotools --pkg=rpm --vmod=foo,bar --vut=baz,qux --verbose tutorial
    mkdir: cannot create directory ‘tutorial’: File exists

Oh nice, it won't overwrite an existing file or directory.

One more time::

    $ rm -r tutorial/
    $ vcdk autotools --pkg=rpm --vmod=foo,bar --vut=baz,qux --verbose tutorial

Still no output, it's so alpha that even a basic option like ``--verbose`` is
not supported... No problem, let's build this project and see what it has::

    $ cd tutorial
    $ tree
    .
    |-- bootstrap
    |-- configure.ac
    |-- Makefile.am
    |-- src
    |   |-- baz.c
    |   |-- baz_options.h
    |   |-- baz.rst.in
    |   |-- Makefile.am
    |   |-- qux.c
    |   |-- qux_options.h
    |   |-- qux.rst.in
    |   |-- vmod_bar.c
    |   |-- vmod_bar.vcc
    |   |-- vmod_foo.c
    |   |-- vmod_foo.vcc
    |   `-- vtc
    |       |-- vmod_bar.vtc
    |       |-- vmod_foo.vtc
    |       |-- vut_baz.vtc
    |       `-- vut_qux.vtc
    `-- tutorial.spec.in

    $ ./bootstrap
    [...]
            ==== tutorial 0.1 ====

            varnish:      6.0.0
            prefix:       /usr
            vmoddir:      /usr/lib/varnish/vmods
            vcldir:       /usr/share/varnish/vcl
            pkgvcldir:    ${vcldir}/${PACKAGE}

            compiler:     gcc
            cflags:       -g -O2
            ldflags:

    $ make -s
    config.status: creating config.h
    config.status: config.h is unchanged
    Making all in src
      VMODTOOL vcc_foo_if.c
      CC       vmod_foo.lo
      CC       vcc_foo_if.lo
      CCLD     libvmod_foo.la
      VMODTOOL vcc_bar_if.c
      CC       vmod_bar.lo
      CC       vcc_bar_if.lo
      CCLD     libvmod_bar.la
      CC       baz.o
      CCLD     baz
      CC       qux.o
      CCLD     qux
      GEN      vmod_foo.3
      GEN      vmod_bar.3
      GEN      baz_synopsis.rst
      GEN      baz_options.rst
    config.status: creating src/baz.rst
      GEN      baz.1
      GEN      qux_synopsis.rst
      GEN      qux_options.rst
    config.status: creating src/qux.rst
      GEN      qux.1

    $ make -s check
    Making check in src
    PASS: vtc/vmod_foo.vtc
    PASS: vtc/vmod_bar.vtc
    PASS: vtc/vut_baz.vtc
    PASS: vtc/vut_qux.vtc
    ============================================================================
    Testsuite summary for tutorial 0.1
    ============================================================================
    # TOTAL: 4
    # PASS:  4
    # SKIP:  0
    # XFAIL: 0
    # FAIL:  0
    # XPASS: 0
    # ERROR: 0
    ============================================================================

Once installed, you may notice that it comes batteries included, even the man
pages are present. The test cases are also installed, and the generated ones
pass both within the build system, and on the local installation::

    $ make install DESTDIR=$PWD/install
    [...]
    $ tree install
    install
    `-- usr
        `-- local
            |-- bin
            |   |-- baz
            |   `-- qux
            |-- lib64
            |   `-- varnish
            |       `-- vmods
            |           |-- libvmod_bar.la
            |           |-- libvmod_bar.so
            |           |-- libvmod_foo.la
            |           `-- libvmod_foo.so
            `-- share
                |-- doc
                |   `-- tutorial
                |       |-- vmod_bar.vcc
                |       |-- vmod_bar.vtc
                |       |-- vmod_foo.vcc
                |       |-- vmod_foo.vtc
                |       |-- vut_baz.vtc
                |       `-- vut_qux.vtc
                `-- man
                    |-- man1
                    |   |-- baz.1
                    |   `-- qux.1
                    `-- man3
                        |-- vmod_bar.3
                        `-- vmod_foo.3

One way to make sure your autotools project is correctly configured is to
run the ``distcheck`` target::

    $ make -s distcheck
    [...]
    ==============================================
    tutorial-0.1 archives ready for distribution:
    tutorial-0.1.tar.gz
    ==============================================

This project comes with the autotools preconfigured, working source code, and
even passing test cases. We can now build an RPM package from the distribution
archive::

    $ rpmbuild -tb tutorial-0.1.tar.gz
    [...]
    Wrote: ~/rpmbuild/RPMS/x86_64/tutorial-0.1-1.fc26.x86_64.rpm
    [...]

At this point all that is left to do is actually implementing the modules and
utilities, but now that we have a working base we should probably use a VCS.
According to the usage message only Git is supported::

    $ git init
    Initialized empty Git repository in ~/tutorial/.git/
    $ git add .
    $ git commit -m 'Initial import'
    [master (root-commit) cf57fa2] Initial import
     20 files changed, 728 insertions(+)
     create mode 100644 .gitignore
     create mode 100644 Makefile.am
     create mode 100755 bootstrap
     create mode 100644 configure.ac
     create mode 100644 src/Makefile.am
     create mode 100644 src/baz.c
     create mode 100644 src/baz.rst.in
     create mode 100644 src/baz_options.h
     create mode 100644 src/qux.c
     create mode 100644 src/qux.rst.in
     create mode 100644 src/qux_options.h
     create mode 100644 src/vmod_bar.c
     create mode 100644 src/vmod_bar.vcc
     create mode 100644 src/vmod_foo.c
     create mode 100644 src/vmod_foo.vcc
     create mode 100644 src/vtc/vmod_bar.vtc
     create mode 100644 src/vtc/vmod_foo.vtc
     create mode 100644 src/vtc/vut_baz.vtc
     create mode 100644 src/vtc/vut_qux.vtc
     create mode 100644 tutorial.spec.in

Thanks to the generated ``.gitignore`` file none of the build artifacts were
accidentally added to the Git index. So now we can finally work on those VMODs
and VUTs, but where do we start?

The answer is not easy, VCDK only generates working projects, it won't help
beyond that. While it's your job to find how to write modules or use
``libvarnishapi``, the autotools plug-in adds ``XXX`` markers where work is
needed::

    $ git grep XXX
    src/baz.c:      /* XXX: process transactions */
    src/baz.c:      /* XXX: parse command line */
    src/baz.c:      /* XXX: run your utility */
    src/baz.rst.in:XXX: document VUT baz
    src/baz_options.h:/* XXX: make your own options */
    src/baz_options.h:/* XXX: or take advantage of existing ones,
    src/qux.c:      /* XXX: process transactions */
    src/qux.c:      /* XXX: parse command line */
    src/qux.c:      /* XXX: run your utility */
    src/qux.rst.in:XXX: document VUT qux
    src/qux_options.h:/* XXX: make your own options */
    src/qux_options.h:/* XXX: or take advantage of existing ones,
    src/vmod_bar.vcc:XXX: document vmod-bar
    src/vmod_bar.vcc:XXX: define vmod-bar interface
    src/vmod_foo.vcc:XXX: document vmod-foo
    src/vmod_foo.vcc:XXX: define vmod-foo interface
    tutorial.spec.in:Summary:       XXX: put your summary here
    tutorial.spec.in:License:       XXX: put your license here
    tutorial.spec.in:URL:           XXX://put.your/url/here
    tutorial.spec.in:XXX: put your long description here
    tutorial.spec.in:* Tue Oct 10 2017 XXX: author <your@email> - 0.1

At least, it gets you that far.

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
