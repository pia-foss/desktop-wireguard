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

# Pre-requisites:
# Install go from https://golang.org

# Build server was set up with 
# wget -c https://dl.google.com/go/go1.13.6.darwin-amd64.pkg
# sudo installer -pkg go1.13.6.darwin-amd64.pkg -target /


ROOT=${ROOT:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}
OUT="$ROOT/out/artifacts"

die() { echo "${__base}:" "$*" 1>&2; exit 1; }

git -C "$ROOT/wireguard-go" diff-index --quiet HEAD -- || die "wireguard-go submodule is not clean, commit or revert changes before building"


git submodule update --init --recursive


rm -rf "$OUT"
mkdir -p "$OUT"

cd "$ROOT/wireguard-go/" || exit
make
cp "$ROOT/wireguard-go/wireguard-go" "$OUT/wireguard-go"
