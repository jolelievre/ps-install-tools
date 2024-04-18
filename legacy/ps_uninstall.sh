#!/bin/sh

baseFolder="/Users/jLelievre/www/prestashop-"
baseDomain="local.prestashop-"
baseDatabase="prestashop-"

echo "Uninstalling a new local prestashop instance"
echo

if test $# -gt 0; then
    suffix=$1
else
    echo "Enter a suffix to identity your installation"
    echo "Example: suffix = module => folder = ${baseFolder}module, domain = ${baseDomain}module"
    echo
    read -p "Suffix: " suffix
fi

targetFolder=${baseFolder}${suffix}
targetDomain=${baseDomain}${suffix}
targetUrl="http://${targetDomain}"
targetDatabase=${baseDatabase}${suffix}

echo
echo "Theses are the $suffix instance informations:"
echo "Project folder: $targetFolder"
echo "Project url: $targetUrl"
echo "Database: $targetDatabase"
echo
echo "WARNING: if you confirm the uninstallation all data and files from this instance will be lost"
read -n 1 -p "Do you confirm uninstallation? [Y/n] " confirm

if test "$confirm" = "n"; then
    exit 1
else
    if test "$confirm" = "N"; then
        exit 1
    fi
fi
echo

stepsIndex=1
stepsNb=4

## 1- Remove project folder
echo "$stepsIndex / $stepsNb: Removing folder $targetFolder"
rm -fR $targetFolder
stepsIndex=$(($stepsIndex+1))

## 2- Drop database
echo "$stepsIndex / $stepsNb: Drop database $targetDatabase"
mysql -u root -e "DROP DATABASE IF EXISTS \`$targetDatabase\`;"
stepsIndex=$(($stepsIndex+1))

## 3- Removing Apache config
echo "$stepsIndex / $stepsNb: Removing apache config for $targetDomain"
vhostFilePath="/opt/homebrew/etc/httpd/extra/sites-available/$targetDomain.conf"
enabledVhostFilePath="/opt/homebrew/etc/httpd/extra/sites-enabled/$targetDomain.conf"
rm -f $vhostFilePath $enabledVhostFilePath
echo "Restarting apache"
sudo apachectl -k stop
sleep 2
sudo apachectl start
stepsIndex=$(($stepsIndex+1))

## 4- Clean /etc/hosts
echo "$stepsIndex / $stepsNb: Cleaning /etc/hosts from $targetDomain"
cat /etc/hosts | sed "/^127\.0\.0\.1.*$targetDomain/d" > /tmp/hosts.clean
sudo mv /tmp/hosts.clean /etc/hosts
