#!/bin/sh

baseFolder="/Users/jLelievre/www/prestashop-"
baseDomain="local.prestashop-"
baseDatabase="prestashop-"

echo "Installing a new local prestashop instance"
echo

if test $# -gt 0; then
    suffix=$1
else
    echo "Enter a suffix for your installation which will define the folder, local domain and name of your shop"
    echo "Example: suffix = module => folder = ${baseFolder}module, domain = ${baseDomain}module"
    echo
    read -p "Suffix: " suffix
fi

targetFolder=${baseFolder}${suffix}
targetDomain=${baseDomain}${suffix}
targetUrl="http://${targetDomain}"
targetDatabase=${baseDatabase}${suffix}
targetName="Prestashop ${suffix}"

upstreamGithub="git@github.com:PrestaShop/PrestaShop.git"
forkedGithub="git@github.com:jolelievre/PrestaShop.git"

echo
echo "Theses are the new instance informations:"
echo "Project folder: $targetFolder"
echo "Project url: $targetUrl"
echo "Database name: $targetDatabase"
