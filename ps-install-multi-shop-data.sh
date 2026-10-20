#!/bin/sh

BASEDIR=$(dirname "$0")
source $BASEDIR/tools/config.sh

confirm_or_exit "Do you confirm installing multi shop data?"

install_multi_shop_data
