#!/bin/bash

# Copyright (c) 2020 Private Internet Access, Inc.
#
# This file is part of the Private Internet Access Desktop Client.
#
# The Private Internet Access Desktop Client is free software: you can
# redistribute it and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.
#
# The Private Internet Access Desktop Client is distributed in the hope that
# it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with the Private Internet Access Desktop Client.  If not, see
# <https://www.gnu.org/licenses/>.

# Build server setup:
# sudo apt install libmnl-dev


ROOT=${ROOT:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}
OUT="$ROOT/out/artifacts"
DEPS="$ROOT/.deps"

die() { echo "${__base}:" "$*" 1>&2; exit 1; }

function strip_symbols() {
    local binaryPath="$1"

    # Strip debugging symbols, but keep a full copy in case it's
    # needed for debugging
    cp "$binaryPath" "$binaryPath.full"
    strip --strip-debug "$binaryPath"
    objcopy --add-gnu-debuglink="$binaryPath.full" "$binaryPath"
}



git -C "$ROOT/wireguard-go" diff-index --quiet HEAD -- || die "wireguard-go submodule is not clean, commit or revert changes before building"

git submodule update --init --recursive

rm -rf "$OUT"
mkdir -p "$OUT"

if [ ! -f "$DEPS/go/bin/go" ]; then
  echo "Extracting go..."
  mkdir -p "$DEPS/"
  tar -xf "$ROOT/deps/linux/go1.13.6.linux-amd64.tar.gz" -C "$DEPS/"
fi
export PATH="$DEPS/go/bin":$PATH


cd "$ROOT/wireguard-go/" || exit
make
cp "$ROOT/wireguard-go/wireguard-go" "$OUT/wireguard-go"

strip_symbols "$OUT/wireguard-go"
