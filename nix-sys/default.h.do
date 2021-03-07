#!/bin/sh -eu
feature=$(cat conf/feature-$2)
src="$2/$feature.c"

redo-ifchange $src conf/feature-$2

cproto -qe < $src > $3
