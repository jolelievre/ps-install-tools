#!/bin/sh

echo "Installing a new multi shop local prestashop instance"
echo

BASEDIR=$(dirname "$0")
$BASEDIR/ps-install.sh $@
$BASEDIR/ps-install-multi-shop-data.sh $@
