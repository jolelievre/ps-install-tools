#!/bin/sh
#
# Usage: ps-infos [--json] [suffix]
#
# Reports everything about a local instance. Text by default, JSON with --json for scripts and
# agents: booleans are true/false, unknown values are null, http_status is a number (0 when the
# shop does not answer) or null when no vhost is enabled.

BASEDIR=$(dirname "$0")

json=0
args=""
for arg in "$@"; do
    if test "$arg" = "--json"; then
        json=1
    else
        args="$args $arg"
    fi
done
set -- $args

# config.sh prints the basic informations unless quietInfos is set
if test $json = 1; then
    quietInfos=1
fi
source $BASEDIR/tools/config.sh

## Collect

# Prints 1 when the command given as arguments succeeds, 0 otherwise
check() {
    if "$@" > /dev/null 2>&1; then echo 1; else echo 0; fi
}

testDatabase="test_$targetDatabase"
databaseExists=$(check db_exists "$targetDatabase")
testDatabaseExists=$(check db_exists "$testDatabase")

folderExists=$(check test -d "$targetFolder")
gitBranch=""
psVersion=""
dumpFile=""
dumpDate=""
if test $folderExists = 1; then
    if test -d "$targetFolder/.git"; then
        gitBranch=$(git -C "$targetFolder" branch --show-current 2>/dev/null)
    fi
    psVersion=$(get_ps_version "$targetFolder")
    if test "$psVersion" = "-"; then
        psVersion=""
    fi
    if test -f "$targetFolder/var/dump.sql"; then
        dumpFile="$targetFolder/var/dump.sql"
        dumpDate=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$dumpFile")
    fi
fi

vhostFile=/opt/homebrew/etc/httpd/extra/sites-enabled/$targetDomain.conf
vhostEnabled=$(check test -f "$vhostFile")
hostsEntry=$(check grep -q "127.0.0.1.*$targetDomain" /etc/hosts)
httpStatus=""
errorLog=""
accessLog=""
# curl and browsers resolve *.localhost to loopback by themselves, so without a vhost the request
# lands on the default Apache vhost and the status would say nothing about this instance
if test $vhostEnabled = 1; then
    httpStatus=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$targetUrl/")
    errorLog=$(sed -n 's/.*ErrorLog "\(.*\)".*/\1/p' "$vhostFile" | head -n 1)
    accessLog=$(sed -n 's/.*CustomLog "\(.*\)" .*/\1/p' "$vhostFile" | head -n 1)
fi
apachePhp=$(sed -n 's#^LoadModule php_module .*/php@\([0-9.]*\)/.*#\1#p' /opt/homebrew/etc/httpd/httpd.conf 2>/dev/null | head -n 1)
cliPhp=$(php -r 'echo PHP_VERSION;' 2>/dev/null)

## Output

# Prints the argument as a JSON string, null when empty
json_string() {
    if test "$1" = ""; then
        echo null
    else
        printf '"%s"\n' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    fi
}
json_bool() {
    if test "$1" = 1; then echo true; else echo false; fi
}
json_number() {
    if test "$1" = ""; then echo null; else printf '%d\n' "$1"; fi
}

if test $json = 1; then
    cat <<JSON
{
  "suffix": $(json_string "$suffix"),
  "name": $(json_string "$targetName"),
  "folder": $(json_string "$targetFolder"),
  "folder_exists": $(json_bool $folderExists),
  "domain": $(json_string "$targetDomain"),
  "url": $(json_string "$targetUrl"),
  "admin_url": $(json_string "$targetUrl/admin-dev"),
  "api_url": $(json_string "$targetUrl/admin-api"),
  "database": $(json_string "$targetDatabase"),
  "database_exists": $(json_bool $databaseExists),
  "test_database": $(json_string "$testDatabase"),
  "test_database_exists": $(json_bool $testDatabaseExists),
  "git_branch": $(json_string "$gitBranch"),
  "prestashop_version": $(json_string "$psVersion"),
  "dump_file": $(json_string "$dumpFile"),
  "dump_date": $(json_string "$dumpDate"),
  "vhost_file": $(json_string "$vhostFile"),
  "vhost_enabled": $(json_bool $vhostEnabled),
  "hosts_entry": $(json_bool $hostsEntry),
  "http_status": $(json_number "$httpStatus"),
  "error_log": $(json_string "$errorLog"),
  "access_log": $(json_string "$accessLog"),
  "php_apache": $(json_string "$apachePhp"),
  "php_cli": $(json_string "$cliPhp"),
  "bo_login": {"email": $(json_string "$email"), "password": $(json_string "$password")},
  "api_client": {"client_id": $(json_string "$apiClientId"), "client_secret": $(json_string "$apiClientSecret")}
}
JSON
    exit 0
fi

yn() {
    if test "$1" = 1; then echo Y; else echo N; fi
}

echo "Test database name: $testDatabase"
echo "Database exists:    $(yn $databaseExists)"
echo "Test DB exists:     $(yn $testDatabaseExists)"
echo

echo "Folder exists:      $(yn $folderExists)"
if test $folderExists = 1; then
    if test "$gitBranch" != ""; then
        echo "Git branch:         $gitBranch"
    else
        echo "Git branch:         - (no .git folder, probably a built archive)"
    fi
    echo "PrestaShop version: ${psVersion:--}"
    if test "$dumpFile" != ""; then
        echo "Data dump:          var/dump.sql from $dumpDate (restored by ps-reset)"
    else
        echo "Data dump:          none (ps-reset needs var/dump.sql, create it with ps-backup)"
    fi
fi
echo

echo "Apache vhost:       $(yn $vhostEnabled) ($vhostFile)"
echo "/etc/hosts entry:   $(yn $hostsEntry)"
if test $vhostEnabled = 1; then
    if test "$httpStatus" = "000"; then
        echo "HTTP status (FO):   unreachable"
    else
        echo "HTTP status (FO):   $httpStatus"
    fi
    echo "Apache logs:        $errorLog"
    echo "                    $accessLog"
else
    echo "HTTP status (FO):   n/a (no vhost enabled)"
fi
echo "PHP (Apache):       ${apachePhp:--} (switch with sphp)"
echo "PHP (CLI):          ${cliPhp:--}"
echo

echo "BO login:           $email / $password"
echo "Admin API client:   $apiClientId / $apiClientSecret (apiClientId/apiClientSecret from config.yml, created by ps-install when the version provides prestashop:api-client)"
