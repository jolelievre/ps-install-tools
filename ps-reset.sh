#!/bin/sh

BASEDIR=$(dirname "$0")
source $BASEDIR/tools/config.sh

confirm_or_exit "Do you confirm resetting data?"

reset_data
