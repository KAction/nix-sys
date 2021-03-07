#!/bin/sh -eu
out=$(cat conf/out)
cdb=$(cat conf/cdb)
manifest=$(cat conf/manifest)
redo-ifchange conf/out conf/cdb conf/manifest

hash=$(echo "$out" | cut -b 12-43)
exec nix-sys-generate               \
      --manifest "$manifest"        \
      --output-config config.h      \
      --output-cdb "$cdb"           \
      --staged-output-cdb index.cdb \
      --hash "$hash"
