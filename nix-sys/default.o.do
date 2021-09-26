#!/bin/sh -eu
cc=$(cat conf/cc)
redo-ifchange conf/cc generate chattr.h

if [ -e "$2.c" ] ; then
	src="$2.c"
else
	redo-ifchange "conf/feature-$2"
	src="$2/$(cat conf/feature-$2).c"
fi

redo-ifchange "$src"
$cc -D ENV_OUT=\"out=${out:-}\" "$src" -c -o $3
