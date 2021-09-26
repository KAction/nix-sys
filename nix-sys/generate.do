#!/bin/sh -eu
out=$(cat conf/out)
cdb=$(cat conf/cdb)
redo-ifchange conf/out conf/cdb conf/manifest

hash=$(echo "$out" | cut -b 12-43)
exec nixsys-preprocess            \
      --output-config config.h    \
      --install-cdb "$cdb"        \
      --output-cdb index.cdb      \
      --hash "$hash"              \
      < conf/manifest
