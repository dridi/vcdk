# Copyright (C) 2017  Dridi Boukelmoune
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

needs_libtool() {
	test -n "$vmod"
}

###########
# bootstrap
###########

bootstrap() {
m4 -Dneeds_libtool=${vmod:+1} << 'EOF'
include(vcdk.m4)dnl
#!/bin/sh

set -e

WORK_DIR="$PWD"
ROOT_DIR="$(dirname "$0")"

test -n "$ROOT_DIR"
cd "$ROOT_DIR"

ifelse(needs_libtool, [1], [dnl
if ! which libtoolize >/dev/null 2>&1
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

ac_config_files() {
cat <<EOF

AC_CONFIG_FILES([
	Makefile
	src/Makefile
EOF

OLD_IFS=$IFS
IFS=,

for v in $vut
do
	printf '\tsrc/%s.rst\n' "$v"
done

IFS=$OLD_IFS

# TODO: packaging files

cat <<EOF
])

EOF
}

configure_ac() {
cat <<EOF
AC_PREREQ([2.68])
AC_INIT([$name], [0.1])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_HEADER([config.h])

AM_INIT_AUTOMAKE([1.12 -Wall -Werror foreign parallel-tests])
AM_SILENT_RULES([yes])
AM_PROG_AR

EOF

needs_libtool &&
cat <<EOF
LT_PREREQ([2.2.6])
LT_INIT([dlopen disable-static])
EOF

cat <<EOF

AC_ARG_WITH([rst2man],
	AS_HELP_STRING(
		[--with-rst2man=PATH],
		[Location of rst2man (auto)]),
	[RST2MAN="\$withval"],
	AC_CHECK_PROGS(RST2MAN, [rst2man rst2man.py], []))

VARNISH_PREREQ([5.2.0])
EOF

test -n "$vmod" &&
tr , ' ' <<EOF
VARNISH_VMODS([$vmod])
EOF

test -n "$vsc" &&
tr , ' ' <<EOF
VARNISH_COUNTERS([$vsc])
EOF

test -n "$vut" &&
tr , ' ' <<EOF
VARNISH_UTILITIES([$vut])
EOF

ac_config_files

cat <<EOF
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
cat << 'EOF'
ACLOCAL_AMFLAGS = -I m4 -I $(VARNISHAPI_DATAROOTDIR)/aclocal

DISTCHECK_CONFIGURE_FLAGS = RST2MAN=:

SUBDIRS = src
EOF
}

#################
# src/Makefile.am
#################

src_makefile_am() {
# TODO: TESTS = tests/vmod_*.vtc tests/vut_*.vtc
# TODO: figure out VSCs
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
	-p vcl_path="\$(abs_top_srcdir)/vcl" \\
	-p vmod_path="\$(abs_builddir)/.libs:\$(vmoddir)"

# Documentation

dist_doc_DATA = \\
foreachc([], [], [VMOD], ([$vmod]), [dnl
	vmod_[]VMOD.vcc \\
])dnl
	\$(TESTS)

dist_man_MANS = \\
foreachc([], [], [VMOD], ([$vmod]), [dnl
	vmod_[]VMOD.3[] \\
])dnl
foreachc([], [], [VUT], ([$vut]), [dnl
	VUT.1 \\
])dnl

foreachc([], [], [VUT], ([$vut]), [dnl
@GENERATE_[]to_upper(VUT)_DOCS@
])dnl

.rst.1:
	\$(AM_V_GEN) \$(RST2MAN) \$< \$@
EOF
}
