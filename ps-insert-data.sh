#!/bin/sh

BASEDIR=$(dirname "$0")
source $BASEDIR/tools/config.sh
source $BASEDIR/tools/tools.sh

read -n 1 -p "Do you confirm inserting data? [Y/n] " confirm
if test "x$confirm" = "xn"; then
    exit 1
else
    if test "x$confirm" = "xN"; then
        exit 1
    fi
fi
echo

insert_data
