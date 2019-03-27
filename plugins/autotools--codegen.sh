# Copyright (C) 2017-2018  Dridi Boukelmoune
# All rights reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

###########
# bootstrap
###########

bootstrap() {
m4 -Dneeds_libtool=${vmod:+1} << 'EOF'
include(vcdk.m4)dnl
#!/bin/sh

set -e
set -u

WORK_DIR=$(pwd)
ROOT_DIR=$(dirname "$0")

cd "$ROOT_DIR"

ifelse(needs_libtool, [1], [dnl
if ! command -v libtoolize >/dev/null
then
	echo "libtoolize: command not found, falling back to glibtoolize" >&2
	alias libtoolize=glibtoolize
fi

])dnl
mkdir -p m4
aclocal
ifelse(needs_libtool, [1], [dnl
libtoolize --copy --force
])dnl
autoheader
automake --add-missing --copy --foreign
autoconf

cd "$WORK_DIR"
"$ROOT_DIR"/configure "$@"
EOF
}

##############
# configure.ac
##############

configure_ac() {
# TODO: packaging files
m4 -Dneeds_libtool=${vmod:+1} << EOF
include(vcdk.m4)dnl
changequote([{], [}])dnl
AC_PREREQ([2.68])
AC_INIT([$name], [0.1])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_HEADER([config.h])

AM_INIT_AUTOMAKE([1.12 -Wall -Werror foreign parallel-tests])
AM_SILENT_RULES([yes])
AM_PROG_AR

ifelse(needs_libtool, {1}, {dnl
LT_PREREQ([2.2.6])
LT_INIT([dlopen disable-static])

})dnl
AC_ARG_WITH([rst2man],
	AS_HELP_STRING(
		[--with-rst2man=PATH],
		[Location of rst2man (auto)]),
	[RST2MAN="\$withval"],
	AC_CHECK_PROGS(RST2MAN, [rst2man rst2man.py], []))

VARNISH_PREREQ([6.0.0])
ifelse({$vmod}, {}, {}, {dnl
VARNISH_VMODS([translit({$vmod}, {,}, { })])
})dnl
ifelse({$vsc}, {}, {}, {dnl
VARNISH_COUNTERS([translit({$vsc}, {,}, { })])
})dnl
ifelse({$vut}, {}, {}, {dnl
VARNISH_UTILITIES([translit({$vut}, {,}, { })])
})dnl

AC_CONFIG_FILES([
	Makefile
	src/Makefile
changequote({[}, {]})dnl
foreachc([], [], [VUT], ([$vut]), [dnl
	src/VUT.rst
])dnl
ifelse([$pkg], [rpm], [dnl
dnl XXX iterate over packagings
	$name.spec
])dnl
changequote([{], [}])dnl
])

AC_OUTPUT

AS_ECHO("
	==== \$PACKAGE_STRING ====

	varnish:      \$VARNISH_VERSION
	prefix:       \$prefix
	vmoddir:      \$vmoddir
	vcldir:       \$vcldir
	pkgvcldir:    \$pkgvcldir

	compiler:     \$CC
	cflags:       \$CFLAGS
	ldflags:      \$LDFLAGS
")
EOF
}

#############
# Makefile.am
#############

makefile_am() {
m4 <<EOF
include(vcdk.m4)dnl
ACLOCAL_AMFLAGS = -I m4 -I @VARNISHAPI_DATAROOTDIR@/aclocal

DISTCHECK_CONFIGURE_FLAGS = RST2MAN=:

SUBDIRS = src
ifelse([$pkg], [rpm], [dnl
dnl XXX iterate over packagings

EXTRA_DIST = $name.spec
])dnl
EOF
}

#################
# src/Makefile.am
#################

tests() {
	OLD_IFS=$IFS
	IFS=,
	for v in $vmod
	do
		printf 'vmod_%s.vtc,' "$v"
	done

	for v in $vut
	do
		printf 'vut_%s.vtc,' "$v"
	done
	IFS=$OLD_IFS
}

manuals() {
	OLD_IFS=$IFS
	IFS=,
	for v in $vmod
	do
		printf 'vmod_%s.3,' "$v"
	done

	for v in $vut
	do
		printf '%s.1,' "$v"
	done
	IFS=$OLD_IFS
}

src_makefile_am() {
# TODO: TESTS = tests/vmod_*.vtc tests/vut_*.vtc
# TODO: figure out VSCs

all_tests=$(tests)
tests_list=${all_tests%,}

all_mans=$(manuals)
mans_list=${all_mans%,}

m4 <<EOF
include(vcdk.m4)dnl
AM_CFLAGS = \$(VARNISHAPI_CFLAGS)
ifelse([$vmod], [], [], [dnl

# Modules

vmod_LTLIBRARIES = \\
foreachc([CONT], [ \\], [VMOD], ([$vmod]), [dnl
	libvmod_[]VMOD.la[]CONT
])dnl
foreachc([], [], [VMOD], ([$vmod]), [dnl

libvmod_[]VMOD[]_la_LDFLAGS = \$(VMOD_LDFLAGS)
libvmod_[]VMOD[]_la_SOURCES = vmod_[]VMOD.c
nodist_libvmod_[]VMOD[]_la_SOURCES = \\
	vcc_[]VMOD[]_if.c \\
	vcc_[]VMOD[]_if.h
])dnl

foreachc([], [], [VMOD], ([$vmod]), [dnl
@BUILD_VMOD_[]to_upper(VMOD)@
])dnl
])dnl ifelse vmod
ifelse([$vut], [], [], [dnl

# Utilities

bin_PROGRAMS = \\
foreachc([CONT], [ \\], [VUT], ([$vut]), [dnl
	VUT[]CONT
])dnl
foreachc([], [], [VUT], ([$vut]), [dnl

VUT[]_LDFLAGS = \$(VARNISHAPI_LIBS)
VUT[]_SOURCES = \\
	VUT.c \\
	VUT[]_options.h
])dnl
])dnl ifelse vut

# Test suite

AM_TESTS_ENVIRONMENT = \\
	PATH="\$(abs_builddir):\$(VARNISH_TEST_PATH):\$(PATH)" \\
	LD_LIBRARY_PATH="\$(VARNISH_LIBRARY_PATH)"
TEST_EXTENSIONS = .vtc
VTC_LOG_COMPILER = varnishtest -v
AM_VTC_LOG_FLAGS = \\
	-p vcl_path="\$(abs_top_srcdir)/vcl:\$(VARNISHAPI_VCLDIR)" \\
	-p vmod_path="\$(abs_builddir)/.libs:\$(vmoddir):\$(VARNISHAPI_VMODDIR)"

TESTS = \\
foreachc([CONT], [ \\], [VTC], ([$tests_list]), [dnl
	vtc/VTC[]CONT
])dnl

# Documentation

dist_doc_DATA = \\
foreachc([], [], [VMOD], ([$vmod]), [dnl
	vmod_[]VMOD.vcc \\
])dnl
	\$(TESTS)

dist_man_MANS = \\
foreachc([CONT], [ \\], [MAN], ([$mans_list]), [dnl
	MAN[]CONT
])dnl

foreachc([], [], [VUT], ([$vut]), [dnl
@GENERATE_[]to_upper(VUT)_DOCS@
])dnl

.rst.1:
	\$(AM_V_GEN) \$(RST2MAN) \$< \$@
EOF
}

src_vmod_c() {
cat <<EOF
#include "config.h"

#include <cache/cache.h>

#include "vcc_$1_if.h"

VCL_STRING
vmod_hello(VRT_CTX)
{

	CHECK_OBJ_NOTNULL(ctx, VRT_CTX_MAGIC);
	return ("vmod-$1");
}
EOF
}

src_vmod_vcc() {
cat <<EOF
\$Module $1 3 "Varnish $1 Module"

DESCRIPTION
===========

This VCC file was generated by VCDK, it is used to for both the VMOD
interface and its manual using reStructuredText.

XXX: document vmod-$1

Example
    ::

        import $1;

        sub vcl_deliver {
	    set resp.http.Hello = $1.hello();
        }

XXX: define vmod-$1 interface

\$Function STRING hello()

Description
    Hello world for vmod-$1

SEE ALSO
========

``vcl``\(7),
``varnishd``\(1)
EOF
}

src_vut_c() {
cat <<EOF
#include "config.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>	// 6.2

#define VOPT_DEFINITION
#define VOPT_INC "$1_options.h"

#include <vapi/voptget.h>
#include <vapi/vsl.h>

#include <vdef.h>
#include <vas.h>
#include <vut.h>

static struct VUT *vut;
static unsigned n_trans = 0;

static void __attribute__((__noreturn__))
usage(int status)
{
	const char **opt;

	fprintf(stderr, "Usage: %s <options>\n\n", vut->progname);
	fprintf(stderr, "Options:\n");
	for (opt = vopt_spec.vopt_usage; *opt != NULL; opt += 2)
		fprintf(stderr, " %-25s %s\n", *opt, *(opt + 1));
	exit(status);
}

static int
dispatch(struct VSL_data *vsl, struct VSL_transaction * const *pt, void *priv)
{

	AN(vsl);
	AN(pt);
	AZ(priv);

	/* XXX: process transactions */

	return (0);
}

static void
sighandler(int sig)
{

	if (vut != NULL)
		VUT_Signaled(vut, sig);
}

int
main(int argc, char * const *argv)
{
	int opt;

	vut = VUT_InitProg(argc, argv, &vopt_spec);
	AN(vut);

	/* XXX: parse command line */

	while ((opt = getopt(argc, argv, vopt_spec.vopt_optstring)) != -1) {
		switch (opt) {
		case 'h':
			usage(EXIT_SUCCESS);
			/* no return */
		case 'w':
			/* Write to file */
			INCOMPL();
			break;
		default:
			if (!VUT_Arg(vut, opt, optarg))
				usage(EXIT_FAILURE);
		}
	}

	if (optind != argc)
		usage(EXIT_FAILURE);

	/* XXX: run your utility */

	vut->dispatch_f = dispatch;
	vut->dispatch_priv = NULL;

	VUT_Signal(sighandler);

	VUT_Setup(vut);
	(void)VUT_Main(vut);
	VUT_Fini(&vut);

	return (EXIT_SUCCESS);
}
EOF
}

src_vut_options_h() {
cat << 'EOF'
#include "vapi/vapi_options.h"
#include "vut_options.h"

/* XXX: make your own options */

#define TEMPLATE_OPT_w							\
	VOPT("w:", "[-w <filename>]", "Output filename",		\
	    "Redirect output to file, the file will be overwritten."	\
	)

/* XXX: or take advantage of existing ones,
 *      a global option can only be used by
 *      one VUT for the whole process.
 */

VUT_OPT_d
VUT_GLOBAL_OPT_D
VUT_OPT_h
VUT_OPT_k
VSL_OPT_L
VUT_OPT_n
VUT_GLOBAL_OPT_P
VUT_OPT_q
VUT_OPT_r
VUT_OPT_t
TEMPLATE_OPT_w
EOF
}

src_vut_rst_in() {
cat <<EOF
=====
$1
=====

-------------------------
$1 utility for Varnish
-------------------------

:Manual section: 1

SYNOPSIS
========

.. include:: @builddir@/$1_synopsis.rst
$1 |synopsis|

DESCRIPTION
===========

This RST file was generated by VCDK, it is processed by autoconf to easily
solve the lack of include path in reStructuredText. This ensures that the
documentation generated by the VUT is always included from the build
directory.

XXX: document VUT $1

The following options are available:

.. include:: @builddir@/$1_options.rst

SIGNALS
=======

SIGUSR1
    Flush any outstanding transactions

SEE ALSO
========

``vcl``\(7),
``varnishd``\(1)

EOF
}

src_vtc_vmod_vtc() {
cat <<EOF
varnishtest "test vmod-$1"

server s1 {
	rxreq
	txresp
} -start

varnish v1 -vcl+backend {
        import $1;

        sub vcl_deliver {
	    set resp.http.Hello = $1.hello();
        }
} -start

client c1 {
	txreq
	rxresp
	expect resp.status == 200
	expect resp.http.Hello == "vmod-$1"
} -run
EOF
}

src_vtc_vut_vtc() {
cat <<EOF
varnishtest "test vut-$1"

server s1 {
	rxreq
	txresp
} -start

varnish v1 -vcl+backend { } -start

client c1 {
	txreq
	rxresp
} -run

shell {$1 -n \${v1_name} -d}
EOF
}

_gitignore() {
m4 <<EOF
include(vcdk.m4)dnl
# build system

.deps/
.libs/
autom4te.cache/
build-aux/
m4/

*.la
*.lo
*.o
*.tar.gz

Makefile
Makefile.in
aclocal.m4
config.h
config.h.in
config.log
config.status
configure
libtool
stamp-h1

# test suite

*.log
*.trs
ifelse([$vmod], [], [], [dnl

# vmodtool

vcc_*_if.[[ch]]
vmod_*.rst
])dnl
ifelse([$vsc], [], [], [dnl

# vsctool

VSC_*.[ch]
VSC_*.rst
])dnl

# man

*.1
*_options.rst
*_synopsis.rst
vmod_*.3
foreachc([], [], [VUT], ([$vut]), [dnl
VUT.rst
])dnl
ifelse([$vut], [], [], [dnl

# bin

foreachc([], [], [VUT], ([$vut]), [dnl
VUT
])dnl
])dnl
ifelse([$pkg], [rpm], [dnl

# rpm

mockbuild/
rpmbuild/

*.rpm
*.spec
])dnl
EOF
}

rpm_spec_in() {
m4 <<EOF
include(vcdk.m4)dnl
%global __debug_package	0
%global __strip	true

%global vmoddir	%{_libdir}/varnish/vmods
%global vcldir	%{_datadir}/varnish/vcl

Name:		@PACKAGE@
Version:	@PACKAGE_VERSION@
Release:	1%{?dist}
Summary:	XXX: put your summary here

License:	XXX: put your license here
URL:		XXX://put.your/url/here
Source:		%{name}-%{version}.tar.gz

BuildRequires:	pkgconfig(varnishapi) >= 6.0.0

%description
XXX: put your long description here

%prep
%setup -q

%build
%configure CFLAGS="%{optflags}" RST2MAN=:
%make_build V=1

%install
%make_install
ifelse([$vmod], [], [], [dnl
rm -f %{buildroot}%{vmoddir}/*.la
])dnl

%check
%make_build check

%files
foreachc([], [], [VUT], ([$vut]), [dnl
%{_bindir}/VUT
])dnl
%{_mandir}/man*/*
foreachc([], [], [VMOD], ([$vmod]), [dnl
%{vmoddir}/libvmod_[]VMOD.so
])dnl

%changelog
* $(LANG=en_US.utf8 date -u '+%a %b %e %Y') XXX: author <your@email> - 0.1
- Initial spec
EOF
}
