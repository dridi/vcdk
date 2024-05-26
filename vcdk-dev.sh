#!/bin/sh
#
# Written by Dridi Boukelmoune <dridi.boukelmoune@gmail.com>
#
# This file is in the public domain.

VCDK_SETUP=$(dirname "$0")
export VCDK_SETUP

exec "$VCDK_SETUP/vcdk" "--plugins=$VCDK_SETUP/plugins" "$@"
