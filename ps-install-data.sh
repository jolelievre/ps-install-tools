#!/bin/sh

BASEDIR=$(dirname "$0")
source $BASEDIR/tools/config.sh

read -n 1 -p "Do you confirm inserting data? [Y/n] " confirm
if test "$confirm" = "n"; then
    exit 1
else
    if test "$confirm" = "N"; then
        exit 1
    fi
fi
echo

insert_data
