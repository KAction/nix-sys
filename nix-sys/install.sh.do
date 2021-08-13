#!/bin/sh
redo-ifchange conf/out conf/cdb install.in
out=$(cat conf/out)
cdb=$(cat conf/cdb)

sed -e "s#@out@#${out}#g" \
	-e "s#@cdb@#${cdb}#g" \
	-e "s#@config@#${config}#g" < install.in > "$3"
chmod +x "$3"
