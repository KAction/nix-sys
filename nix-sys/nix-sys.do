#!/bin/sh -eu
ld=$(cat conf/ld)
objs="main.o chattr.o"
redo-ifchange conf/ld $objs
$ld $objs -lcdb -o $3
