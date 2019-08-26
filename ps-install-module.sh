#!/bin/sh

if test $# -gt 1; then
    modulePath=$2
else
    echo "Usage: ps-install-module.sh suffix module_path"
    exit 1
fi

echo "Installing a module from $modulePath in PrestaShop"
echo

BASEDIR=$(dirname "$0")
source $BASEDIR/tools/config.sh

if test -d $modulePath; then
    moduleFolderPath=$modulePath
    modulePath="$moduleFolderPath.zip"
    echo "Creating archive form module at $modulePath"
    rm -f $modulePath
    zip -r $modulePath $moduleFolderPath
fi

npm run install-module $targetUrl/admin-dev $modulePath
