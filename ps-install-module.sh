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
    moduleName=$(basename $moduleFolderPath)
else
    moduleName=$(basename $modulePath)
    moduleName=$(echo "$moduleName" | cut -f 1 -d '.')
    moduleFolderPath=/tmp/$moduleName/
    rm -fR $moduleFolderPath
    echo "unzip $modulePath $moduleFolderPath"
    unzip $modulePath -d /tmp
fi

targetModulePath="$targetFolder/modules/$moduleName/"
if ! test -d $targetModulePath; then
    mkdir $targetModulePath
fi
cp -R $moduleFolderPath/* $targetModulePath

if test -f $targetFolder/bin/console; then
    # In 1.7 we have use a command to install the module
    cd $targetFolder
    php ./bin/console prestashop:module install $moduleName
else
    # This is for 1.6 versions, we should check the target version an run the command for 1.7 versions
    cd $BASEDIR
    npm run install-module $targetUrl/admin-dev $modulePath
fi
