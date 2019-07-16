#!/bin/sh

if [ -z $BASEDIR ]; then
    BASEDIR=$(dirname "$0")/..
fi
source $BASEDIR/tools/tools.sh

load_config

if test $# -gt 0; then
    suffix=$1
else
    echo "Enter a suffix for your installation which will define the folder, local domain and name of your shop"
    echo "Example: suffix = module => folder = ${baseFolder}module, domain = ${baseDomain}module"
    echo
    read -p "Suffix: " suffix
    echo
fi

targetFolder=${baseFolder}${suffix}
targetDomain=${baseDomain}${suffix}
targetUrl="http://${targetDomain}"
targetDatabase=${baseDatabase}${suffix}
targetName="Prestashop ${suffix}"

echo "These are the $suffix instance informations:"
echo "Project folder: $targetFolder"
echo "Project url: $targetUrl"
echo "Database name: $targetDatabase"
