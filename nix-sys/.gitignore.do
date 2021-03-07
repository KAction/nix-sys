#!/bin/sh -eu

# git does not recognize ./foo as pattern matching file named "foo".
redo-targets | sed 's/..//' > $3
cat << EOF >> $3
.gitignore
.dep.*
.depend.*
.target.*
.lock.*
index.cdb
config.h
conf/*
EOF

