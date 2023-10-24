#!/bin/sh
# Copyright 2009 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Environment variables that control make.bash:
#
# GOROOT_FINAL: The expected final Go root, baked into binaries.
# The default is the location of the Go tree during the build.
#
# GOHOSTARCH: The architecture for host tools (compilers and
# binaries).  Binaries of this type must be executable on the current
# system, so the only common reason to set this is to set
# GOHOSTARCH=386 on an amd64 machine.
#
# GOARCH: The target architecture for installed packages and tools.
#
# GOOS: The target operating system for installed packages and tools.
#
# GO_GCFLAGS: Additional 5g/6g/8g arguments to use when
# building the packages and commands.
#
# GO_LDFLAGS: Additional 5l/6l/8l arguments to use when
# building the commands.
#
# GO_CCFLAGS: Additional 5c/6c/8c arguments to use when
# building.
#
# CGO_ENABLED: Controls cgo usage during the build. Set it to 1
# to include all cgo related files, .c and .go file with "cgo"
# build directive, in the build. Set it to 0 to ignore them.
#
# GO_EXTLINK_ENABLED: Set to 1 to invoke the host linker when building
# packages that use cgo.  Set to 0 to do all linking internally.  This
# controls the default behavior of the linker's -linkmode option.  The
# default value depends on the system.
#
# CC: Command line to run to compile C code for GOHOSTARCH.
# Default is "gcc". Also supported: "clang".
#
# CC_FOR_TARGET: Command line to run to compile C code for GOARCH.
# This is used by cgo.  Default is CC.
#
# CXX_FOR_TARGET: Command line to run to compile C++ code for GOARCH.
# This is used by cgo. Default is CXX, or, if that is not set,
# "g++" or "clang++".
#
# GO_DISTFLAGS: extra flags to provide to "dist bootstrap". Use "-s"
# to build a statically linked toolchain.

set -e

# Finally!  Run the build.

echo '# Building C bootstrap tool.'
echo cmd/dist
export GOROOT="$(cd .. && pwd)"
GOROOT_FINAL="${GOROOT_FINAL:-$GOROOT}"
DEFGOROOT='-DGOROOT_FINAL="'"$GOROOT_FINAL"'"'

mflag=""
case "$GOHOSTARCH" in
amd64) mflag=-m64;;
esac
${CC:-gcc} $mflag -O2 -Wall -Werror -o cmd/dist/dist -Icmd/dist "$DEFGOROOT" cmd/dist/*.c

# -e doesn't propagate out of eval, so check success by hand.
eval $(./cmd/dist/dist env -p || echo FAIL=true)
if [ "$FAIL" = true ]; then
	exit 1
fi

echo

if [ "$1" = "--dist-tool" ]; then
	# Stop after building dist tool.
	mkdir -p "$GOTOOLDIR"
	if [ "$2" != "" ]; then
		cp cmd/dist/dist "$2"
	fi
	mv cmd/dist/dist "$GOTOOLDIR"/dist
	exit 0
fi

echo "# Building compilers and Go bootstrap tool for host, $GOHOSTOS/$GOHOSTARCH."
buildall="-a"
if [ "$1" = "--no-clean" ]; then
	buildall=""
	shift
fi
./cmd/dist/dist bootstrap $buildall $GO_DISTFLAGS -v # builds go_bootstrap
# Delay move of dist tool to now, because bootstrap may clear tool directory.
mv cmd/dist/dist "$GOTOOLDIR"/dist
"$GOTOOLDIR"/go_bootstrap clean -i std
echo

if [ "$GOHOSTARCH" != "$GOARCH" -o "$GOHOSTOS" != "$GOOS" ]; then
	echo "# Building packages and commands for host, $GOHOSTOS/$GOHOSTARCH."
	# CC_FOR_TARGET is recorded as the default compiler for the go tool. When building for the host, however,
	# use the host compiler, CC, from `cmd/dist/dist env` instead.
	CC=$CC GOOS=$GOHOSTOS GOARCH=$GOHOSTARCH \
		"$GOTOOLDIR"/go_bootstrap install -ccflags "$GO_CCFLAGS" -gcflags "$GO_GCFLAGS" -ldflags "$GO_LDFLAGS" -v std
	echo
fi

echo "# Building packages and commands for $GOOS/$GOARCH."
CC=$CC_FOR_TARGET "$GOTOOLDIR"/go_bootstrap install $GO_FLAGS -ccflags "$GO_CCFLAGS" -gcflags "$GO_GCFLAGS" -ldflags "$GO_LDFLAGS" -v std
echo
