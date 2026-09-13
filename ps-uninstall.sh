#!/bin/sh

BASEDIR=$(dirname "$0")

# config.sh only handles one instance: the whole list of suffixes is kept aside and config.sh is
# sourced with the first one. Without any argument it detects the instance from the current folder
# or asks for a suffix, and that single suffix becomes the list.
suffixes="$*"
quietInfos=1
source $BASEDIR/tools/config.sh $1
if test "$suffixes" = ""; then
    suffixes=$suffix
fi
instancesNb=`echo $suffixes | wc -w | tr -d ' '`

if test $instancesNb -gt 1; then
    echo "Uninstalling $instancesNb local prestashop instances"
else
    echo "Uninstalling a local prestashop instance"
fi
echo

for suffix in $suffixes; do
    set_target_instance $suffix
    echo "Instance $suffix:"
    echo "  Project folder:     $targetFolder"
    echo "  Project url:        $targetUrl"
    echo "  Database name:      $targetDatabase"
done

echo
echo "WARNING: if you confirm the uninstallation all data and files from the instances listed above will be lost"
read -n 1 -p "Do you confirm uninstallation? [Y/n] " confirm

if test "$confirm" = "n"; then
    exit 1
else
    if test "$confirm" = "N"; then
        exit 1
    fi
fi
echo

stepsNb=4

## 1- Stop apache, once for the whole list
echo "1 / $stepsNb: Stopping apache"
# run_sudo names the instances it works for, so suffix holds the whole list outside of the loops
suffix=$suffixes
run_sudo "stop Apache before removing the vhosts of $suffixes" brew services stop httpd

## 2- Remove folder, databases and vhost of each instance
instanceIndex=1
for suffix in $suffixes; do
    set_target_instance $suffix
    echo
    echo "2 / $stepsNb: Removing instance $suffix ($instanceIndex / $instancesNb)"

    echo "  Removing folder $targetFolder"
    rm -fR $targetFolder

    echo "  Drop database $targetDatabase"
    mysql -u root -e "DROP DATABASE IF EXISTS \`$targetDatabase\`;"
    echo "  Drop database test_$targetDatabase"
    mysql -u root -e "DROP DATABASE IF EXISTS \`test_$targetDatabase\`;"

    echo "  Removing apache config for $targetDomain"
    vhostFilePath="/opt/homebrew/etc/httpd/extra/sites-available/$targetDomain.conf"
    enabledVhostFilePath="/opt/homebrew/etc/httpd/extra/sites-enabled/$targetDomain.conf"
    rm -f $vhostFilePath $enabledVhostFilePath

    instanceIndex=$(($instanceIndex+1))
done
echo

## 3- Restart apache, once every vhost is gone
echo "3 / $stepsNb: Restarting apache"
suffix=$suffixes
run_sudo "restart Apache after removing the vhosts of $suffixes" brew services restart httpd

## 4- Clean /etc/hosts from every domain in one pass
echo "4 / $stepsNb: Cleaning /etc/hosts"
hostsFilter=""
for suffix in $suffixes; do
    set_target_instance $suffix
    echo "  Removing $targetDomain from /etc/hosts"
    hostsFilter="$hostsFilter -e /^127\.0\.0\.1.*$targetDomain/d"
done
suffix=$suffixes
sed $hostsFilter /etc/hosts > /tmp/hosts.clean
run_sudo "remove the domains of $suffixes from /etc/hosts" mv /tmp/hosts.clean /etc/hosts
