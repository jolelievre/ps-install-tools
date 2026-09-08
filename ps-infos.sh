#!/bin/sh

BASEDIR=$(dirname "$0")
source $BASEDIR/tools/config.sh

# Prints Y when the command given as arguments succeeds, N otherwise
yn() {
    if "$@" > /dev/null 2>&1; then echo Y; else echo N; fi
}

echo "Test database name: test_$targetDatabase"
echo "Database exists:    $(yn db_exists "$targetDatabase")"
echo "Test DB exists:     $(yn db_exists "test_$targetDatabase")"
echo

if test -d $targetFolder; then
    echo "Folder exists:      Y"
    if test -d $targetFolder/.git; then
        echo "Git branch:         $(git -C $targetFolder branch --show-current 2>/dev/null)"
    else
        echo "Git branch:         - (no .git folder, probably a built archive)"
    fi
    echo "PrestaShop version: $(get_ps_version $targetFolder)"
    if test -f $targetFolder/var/dump.sql; then
        echo "Data dump:          var/dump.sql from $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' $targetFolder/var/dump.sql) (restored by ps-reset)"
    else
        echo "Data dump:          none (ps-reset needs var/dump.sql, create it with ps-backup)"
    fi
else
    echo "Folder exists:      N"
fi
echo

vhostEnabled=/opt/homebrew/etc/httpd/extra/sites-enabled/$targetDomain.conf
echo "Apache vhost:       $(yn test -f $vhostEnabled) ($vhostEnabled)"
echo "/etc/hosts entry:   $(yn grep -q "127.0.0.1.*$targetDomain" /etc/hosts)"
# curl and browsers resolve *.localhost to loopback by themselves, so without a vhost the request
# lands on the default Apache vhost and the status would say nothing about this instance
if test -f $vhostEnabled; then
    httpStatus=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 $targetUrl/)
    if test "$httpStatus" = "000"; then
        httpStatus="unreachable"
    fi
else
    httpStatus="n/a (no vhost enabled)"
fi
echo "HTTP status (FO):   $httpStatus"
apachePhp=$(sed -n 's#^LoadModule php_module .*/php@\([0-9.]*\)/.*#\1#p' /opt/homebrew/etc/httpd/httpd.conf 2>/dev/null | head -n 1)
echo "PHP (Apache):       ${apachePhp:--} (switch with sphp)"
echo "PHP (CLI):          $(php -v 2>/dev/null | head -n 1)"
echo

echo "BO login:           $email / $password"
echo "Admin API client:   test / 18c7b983c2eaa22a111609ce2b1c435e (created by ps-install when the version provides prestashop:api-client)"
