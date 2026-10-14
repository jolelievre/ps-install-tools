#!/bin/sh
#
# PHP version per instance: a .php-version file at the root of the instance selects the PHP of
# the CLI, and the web is served by a PHP-FPM pool of that version, run by masters of these tools:
# <fpmFolder>/<version>/php-fpm.conf, <fpmFolder>/<version>/pools/<suffix>.conf,
# <fpmFolder>/sockets/<suffix>.sock, ~/Library/LaunchAgents/<label>-<version>.plist.
# The Homebrew PHP configs and httpd.conf are not changed.

fpmLaunchLabel=com.prestashop.ps-install-tools.php-fpm

brew_prefix() {
    if test "$HOMEBREW_PREFIX" != ""; then
        echo "$HOMEBREW_PREFIX"
    else
        brew --prefix 2>/dev/null || echo /opt/homebrew
    fi
}

# Prints the Homebrew folder of the PHP version given as argument, returns 1 when not installed.
# The latest version may only be installed as the php formula, without a php@X.Y folder.
php_folder_for_version() {
    local prefix=$(brew_prefix)
    if test -x "$prefix/opt/php@$1/bin/php"; then
        echo "$prefix/opt/php@$1"
        return 0
    fi
    if test -x "$prefix/opt/php/bin/php" && test "$("$prefix/opt/php/bin/php" -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')" = "$1"; then
        echo "$prefix/opt/php"
        return 0
    fi
    return 1
}

php_binary_for_version() {
    local folder
    folder=$(php_folder_for_version "$1") || return 1
    echo "$folder/bin/php"
}

php_fpm_binary_for_version() {
    local folder
    folder=$(php_folder_for_version "$1") || return 1
    test -x "$folder/sbin/php-fpm" || return 1
    echo "$folder/sbin/php-fpm"
}

installed_php_versions() {
    local prefix=$(brew_prefix) folder version
    for folder in "$prefix"/opt/php@* "$prefix/opt/php"; do
        if test -x "$folder/bin/php"; then
            "$folder/bin/php" -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION, "\n";' 2>/dev/null
        fi
    done | sort -t. -k1,1n -k2,2n -u
}

get_instance_php_version() {
    if test -f "$1/.php-version"; then
        head -n 1 "$1/.php-version" | tr -d '[:space:]'
    fi
}

# Reads --php <version> from the arguments: sets phpVersionOption, and otherArgs to the others
parse_php_option() {
    phpVersionOption=""
    otherArgs=""
    while test $# -gt 0; do
        case "$1" in
            --php)
                if test "$2" = ""; then
                    echo "--php needs a version, for example --php 8.4" >&2
                    return 1
                fi
                phpVersionOption=$2
                shift
                ;;
            --php=*)
                phpVersionOption=${1#--php=}
                ;;
            *)
                otherArgs="$otherArgs $1"
                ;;
        esac
        shift
    done
}

# Called by set_target_instance: puts the bin folder of the pinned version first in the PATH, so
# composer, bin/console and every sub process use it. Sets instancePhpVersion (empty for the
# global PHP) and instancePhp (empty when the pinned version is not installed).
use_instance_php() {
    # PATH from before the first call, so successive instances do not stack their folders
    if test "$basePath" = ""; then
        basePath=$PATH
    fi
    PATH=$basePath
    instancePhpVersion=$(get_instance_php_version "$targetFolder")
    if test "$instancePhpVersion" = ""; then
        instancePhp=$(command -v php)
    else
        instancePhp=$(php_binary_for_version "$instancePhpVersion")
        if test "$instancePhp" != ""; then
            PATH="$(dirname "$instancePhp"):$PATH"
        fi
    fi
    export PATH
}

require_instance_php() {
    if test "$instancePhp" = ""; then
        echo "PHP $instancePhpVersion is required by $targetFolder/.php-version but is not installed (brew install php@$instancePhpVersion)" >&2
        return 1
    fi
}

# Excluded from git so it never shows in git status of the clone
pin_instance_php() {
    echo "$1" > "$targetFolder/.php-version"
    if test -d "$targetFolder/.git" && ! grep -qx '/.php-version' "$targetFolder/.git/info/exclude" 2>/dev/null; then
        mkdir -p "$targetFolder/.git/info"
        echo '/.php-version' >> "$targetFolder/.git/info/exclude"
    fi
    use_instance_php
}

unpin_instance_php() {
    rm -f "$targetFolder/.php-version"
    use_instance_php
}

## PHP-FPM

instance_fpm_socket() {
    echo "$fpmFolder/sockets/$suffix.sock"
}

instance_php_log() {
    echo "$HOME/www/var/logs/prestashop-$suffix.php-error.log"
}

fpm_launch_label() {
    echo "$fpmLaunchLabel-$1"
}

fpm_launch_plist() {
    echo "$HOME/Library/LaunchAgents/$(fpm_launch_label "$1").plist"
}

fpm_master_loaded() {
    launchctl print "gui/$(id -u)/$(fpm_launch_label "$1")" > /dev/null 2>&1
}

# Versions with at least one pool
fpm_versions() {
    local folder
    for folder in "$fpmFolder"/*/pools; do
        if ls "$folder/"*.conf > /dev/null 2>&1; then
            basename "$(dirname "$folder")"
        fi
    done
}

# Version whose master serves the instance given as argument, nothing without a pool
fpm_pool_version() {
    local version
    for version in $(fpm_versions); do
        if test -f "$fpmFolder/$version/pools/$1.conf"; then
            echo "$version"
            return 0
        fi
    done
}

write_fpm_master() {
    local version=$1 fpmBinary
    fpmBinary=$(php_fpm_binary_for_version "$version") || {
        echo "No php-fpm binary for PHP $version (brew install php@$version)" >&2
        return 1
    }
    mkdir -p "$fpmFolder/$version/pools" "$fpmFolder/sockets" "$HOME/Library/LaunchAgents"
    cat > "$fpmFolder/$version/php-fpm.conf" <<EOM
; Generated by ps-install-tools, PHP-FPM master of PHP $version (pools of the instances in pools/)
[global]
pid = $fpmFolder/$version/php-fpm.pid
error_log = $fpmFolder/$version/php-fpm.log
daemonize = no
include = $fpmFolder/$version/pools/*.conf
EOM
    cat > "$(fpm_launch_plist "$version")" <<EOM
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$(fpm_launch_label "$version")</string>
    <key>ProgramArguments</key>
    <array>
        <string>$fpmBinary</string>
        <string>--nodaemonize</string>
        <string>--fpm-config</string>
        <string>$fpmFolder/$version/php-fpm.conf</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>$fpmFolder/$version/php-fpm.log</string>
</dict>
</plist>
EOM
}

write_fpm_pool() {
    local version=$1
    mkdir -p "$fpmFolder/$version/pools" "$(dirname "$(instance_php_log)")"
    cat > "$fpmFolder/$version/pools/$suffix.conf" <<EOM
; Generated by ps-install-tools, PHP $version pool of the instance $suffix ($targetFolder)
[$suffix]
listen = $(instance_fpm_socket)
pm = ondemand
pm.max_children = 10
pm.process_idle_timeout = 60s
; Same environment and logs as mod_php would give
clear_env = no
catch_workers_output = yes
php_admin_flag[log_errors] = on
php_admin_value[error_log] = $(instance_php_log)
EOM
}

# Starts or reloads the master of the version given as argument, or stops it when it has no pool
# left: a master refuses to start without any pool
sync_fpm_master() {
    local version=$1 plist label
    plist=$(fpm_launch_plist "$version")
    label="gui/$(id -u)/$(fpm_launch_label "$version")"
    if ls "$fpmFolder/$version/pools/"*.conf > /dev/null 2>&1; then
        write_fpm_master "$version" || return 1
        if fpm_master_loaded "$version"; then
            echo "Reloading PHP-FPM $version"
            launchctl kill USR2 "$label"
        else
            echo "Starting PHP-FPM $version"
            launchctl bootstrap "gui/$(id -u)" "$plist"
        fi
    else
        if fpm_master_loaded "$version"; then
            echo "Stopping PHP-FPM $version (no instance left)"
            launchctl bootout "$label"
        fi
        rm -f "$plist"
    fi
}

wait_fpm_socket() {
    local socket=$(instance_fpm_socket) i=0
    while test $i -lt 50; do
        test -S "$socket" && return 0
        sleep 0.1
        i=$(($i+1))
    done
    echo "The socket $socket did not show up, see $fpmFolder/$instancePhpVersion/php-fpm.log" >&2
    return 1
}

wait_fpm_socket_gone() {
    local socket=$(instance_fpm_socket) i=0
    while test -S "$socket" && test $i -lt 50; do
        sleep 0.1
        i=$(($i+1))
    done
    rm -f "$socket"
}

# Moves the pool of the current instance to the master of its pinned version
enable_instance_fpm() {
    local previousVersion
    previousVersion=$(fpm_pool_version "$suffix")
    # The previous master goes first: when it drops the pool it deletes the socket file, which
    # would be the one of the new master if it had started before
    if test "$previousVersion" != "" && test "$previousVersion" != "$instancePhpVersion"; then
        rm -f "$fpmFolder/$previousVersion/pools/$suffix.conf"
        sync_fpm_master "$previousVersion"
        wait_fpm_socket_gone
    fi
    write_fpm_pool "$instancePhpVersion"
    sync_fpm_master "$instancePhpVersion" || return 1
    wait_fpm_socket
}

disable_instance_fpm() {
    local previousVersion
    previousVersion=$(fpm_pool_version "$suffix")
    if test "$previousVersion" != ""; then
        echo "Removing PHP-FPM $previousVersion pool of $suffix"
        rm -f "$fpmFolder/$previousVersion/pools/$suffix.conf"
        sync_fpm_master "$previousVersion"
    fi
    rm -f "$(instance_fpm_socket)"
}

## Apache

# Vhost lines sending the PHP files to the pool, nothing for the global PHP (httpd.conf applies).
# The socket does not depend on the version, so changing the version keeps the vhost.
php_vhost_handler() {
    if test "$instancePhpVersion" = ""; then
        return
    fi
    cat <<EOM
    # PHP-FPM pool of the instance (ps-php)
    <FilesMatch \.php$>
        SetHandler "proxy:unix:$(instance_fpm_socket)|fcgi://ps-$suffix"
    </FilesMatch>
    # Module installs and upgrades take more than 60 seconds
    ProxyTimeout 600
EOM
}

# Replaces the PHP handler of the vhost file given as argument, keeps the other lines (ps-ngrok domains)
update_vhost_php_handler() {
    PHP_HANDLER="$(php_vhost_handler)" awk '
        /# PHP(-FPM pool)? of the instance/ { skip = 1 }
        skip { if (/ProxyTimeout/) skip = 0; next }
        /<\/VirtualHost>/ && ENVIRON["PHP_HANDLER"] != "" { print ENVIRON["PHP_HANDLER"] }
        { print }
    ' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

vhost_php_up_to_date() {
    if test "$instancePhpVersion" = ""; then
        ! grep -q "proxy:unix:" "$1"
    else
        grep -qF "proxy:unix:$(instance_fpm_socket)|fcgi://ps-$suffix\"" "$1"
    fi
}

apache_has_proxy_fcgi() {
    "$(brew_prefix)/bin/apachectl" -M 2>/dev/null | grep -q 'proxy_fcgi_module'
}

check_php_requirements() {
    if ! echo "$1" | grep -qE '^[0-9]+\.[0-9]+$'; then
        echo "Invalid PHP version $1, expected <major>.<minor> (use ps-php <suffix> global to go back to the global PHP)" >&2
        return 1
    fi
    if ! php_fpm_binary_for_version "$1" > /dev/null; then
        echo "PHP $1 with php-fpm is not installed (brew install php@$1), installed versions: $(installed_php_versions | xargs)" >&2
        return 1
    fi
    if ! apache_has_proxy_fcgi; then
        print_apache_fpm_requirements
        return 1
    fi
}

print_apache_fpm_requirements() {
    cat >&2 <<EOM
Apache needs mod_proxy_fcgi to serve an instance with its own PHP version. Uncomment these lines
in $(brew_prefix)/etc/httpd/httpd.conf, restart Apache, then run ps-php doctor:
    LoadModule proxy_module lib/httpd/modules/mod_proxy.so
    LoadModule proxy_fcgi_module lib/httpd/modules/mod_proxy_fcgi.so
EOM
}
