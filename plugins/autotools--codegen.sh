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
cat << 'EOF'
#!/bin/sh

set -e

WORK_DIR="$PWD"
ROOT_DIR="$(dirname "$0")"

test -n "$ROOT_DIR"
cd "$ROOT_DIR"

EOF

needs_libtool &&
cat <<EOF
if ! which libtoolize >/dev/null 2>&1
then
	echo "libtoolize: command not found, falling back to glibtoolize" >&2
	alias libtoolize=glibtoolize
fi

EOF

cat <<EOF
mkdir -p m4
aclocal
EOF

needs_libtool &&
cat <<EOF
libtoolize --copy --force
EOF

cat << 'EOF'
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

vmod_ltlibraries() {
cat <<EOF

# Modules

vmod_LTLIBRARIES = \\
EOF

OLD_IFS=$IFS
IFS=,

for v in $vmod
do
	printf '\tlibvmod_%s.la \\\n' "$v"
done

for v in $vmod
do
cat <<EOF

libvmod_${v}_la_LDFLAGS = \$(VMOD_LDFLAGS)
libvmod_${v}_la_SOURCES = vmod_${v}.c
nodist_libvmod_${v}_la_SOURCES = \\
	vcc_${v}_if.c \\
	vcc_${v}_if.h
EOF
done

echo

for v in $vmod
do
cat <<EOF
@BUILD_VMOD_$(to_upper "$v")@
EOF
done

IFS=$OLD_IFS

# TODO: figure VSCs out
}

bin_programs() {
cat <<EOF

# Utilities

bin_PROGRAMS = \\
EOF

OLD_IFS=$IFS
IFS=,

for v in $vut
do
	printf '\t%s \\\n' "$v"
done

for v in $vut
do
cat <<EOF

${v}_LDFLAGS = \$(VARNISHAPI_LIBS)
${v}_SOURCES = \\
	${v}.c \\
	${v}_options.h
EOF
done

IFS=$OLD_IFS
}

src_makefile_am() {
cat << 'EOF'
AM_CFLAGS = $(VARNISHAPI_CFLAGS)
EOF

test -n "$vmod" && vmod_ltlibraries
test -n "$vut" && bin_programs

cat << 'EOF'

# Test suite

AM_TESTS_ENVIRONMENT = \
	PATH="$(abs_builddir):$(VARNISH_TEST_PATH):$(PATH)" \
	LD_LIBRARY_PATH="$(VARNISH_LIBRARY_PATH)"
TEST_EXTENSIONS = .vtc
VTC_LOG_COMPILER = varnishtest -v
AM_VTC_LOG_FLAGS = \
	-p vcl_path="$(abs_top_srcdir)/vcl" \
	-p vmod_path="$(abs_builddir)/.libs:$(vmoddir)"
EOF


# TODO: TESTS = tests/vmod_*.vtc tests/vut_*.vtc
# TODO: dist_doc_DATA

cat <<EOF

# Documentation

dist_man_MANS = \\
EOF

OLD_IFS=$IFS
IFS=,

for v in $vmod
do
	printf '\tvmod_%s.3 \\\n' "$v"
done

for v in $vut
do
	printf '\t%s.1 \\\n' "$v"
done

echo

for v in $vut
do
	printf '@GENERATE_%s_DOCS@\n' "$(to_upper "$v")"
done

cat << 'EOF'

.rst.1:
	$(AM_V_GEN) $(RST2MAN) $< $@
EOF
}
