#!/bin/sh

parse_yaml() {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
      printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
   }'
}

ask_config() {
    if [ $configAsked -eq 0 ]; then
        configAsked=1
        echo "You need to update your config first (new keys in config.yml.dist, defaults kept without a terminal):" >&2
        echo >&2
    fi
    read -p "$configName [$defaultValue]: " userValue
    if test "$userValue" = ""; then
        userValue=$defaultValue
    fi
    echo "$configName: \"$userValue\"" >> $BASEDIR/config.yml
}

prepare_config() {
    configAsked=0
    defaultConfigs=`parse_yaml $BASEDIR/config.yml.dist`
    for defaultConfig in $defaultConfigs; do
        configName=`echo $defaultConfig | sed s/=.*//`
        defaultValue=`echo $defaultConfig | sed s/^.*=\"// | sed s/\"$//`
        if [ -f $BASEDIR/config.yml ]; then
            cat $BASEDIR/config.yml | grep "$configName:" > /dev/null
            if [ $? -ne 0 ]; then
                ask_config
            fi
        else
            ask_config
        fi
    done
}

load_config() {
    prepare_config
    userConfig=`parse_yaml $BASEDIR/config.yml`
    eval $userConfig
}

insert_data() {
    clear_cache
    cd $targetFolder
    if test -f $targetFolder/install-dev/index_cli.php; then
        installCli=install-dev/index_cli.php
    elif test -f $targetFolder/install/index_cli.php; then
        installCli=install/index_cli.php
    else
        echo Could not find CLI endpoint
        exit 1
    fi
    language=$PS_LANGUAGE
    country=$PS_COUNTRY

    if [ "$language" = "" ]; then
        language=en
    fi
    if [ "$country" = "" ]; then
        country=fr
    fi

    echo Dropping database $targetDatabase...
    mysql -u root -e "DROP DATABASE IF EXISTS \`$targetDatabase\`;"
    echo "Inserting fixtures data for domain $targetDomain database $targetDatabase..."
    echo "Command used: php $installCli \
        --language=$language \
        --country=$country \
        --domain=$targetDomain \
        --base_uri=/ \
        --db_server=127.0.0.1 \
        --db_user=root \
        --db_name=$targetDatabase \
        --db_create=1 \
        --firstname=\"$firstName\" \
        --lastname=\"$lastName\" \
        --name=\"$targetName\" \
        --email=$email \
        --password=\"$password\""
    php $installCli \
        --language=$language \
        --country=$country \
        --domain=$targetDomain \
        --base_uri=/ \
        --db_server=127.0.0.1 \
        --db_user=root \
        --db_name=$targetDatabase \
        --db_create=1 \
        --firstname="$firstName" \
        --lastname="$lastName" \
        --name="$targetName" \
        --email=$email \
        --password="$password"

    # Preset SMTP settings
    if [ "$smtpUser" != "" ] && [ "$smtpPass" != "" ]; then
        echo "Setup SMTP settings"
        echo "SMTP server: $smtpServer"
        echo "SMTP user: $smtpUser"
        echo "SMTP pass: $smtpPass"
        echo "SMTP port: $smtpPort"
        mysql -u root -D $targetDatabase -e "UPDATE \`ps_configuration\` SET \`value\` = \"2\" WHERE \`name\` = \"PS_MAIL_METHOD\""
        mysql -u root -D $targetDatabase -e "UPDATE \`ps_configuration\` SET \`value\` = \"$smtpServer\" WHERE \`name\` = \"PS_MAIL_SERVER\""
        mysql -u root -D $targetDatabase -e "UPDATE \`ps_configuration\` SET \`value\` = \"$smtpUser\" WHERE \`name\` = \"PS_MAIL_USER\""
        mysql -u root -D $targetDatabase -e "UPDATE \`ps_configuration\` SET \`value\` = \"$smtpPass\" WHERE \`name\` = \"PS_MAIL_PASSWD\""
        mysql -u root -D $targetDatabase -e "UPDATE \`ps_configuration\` SET \`value\` = \"$smtpPort\" WHERE \`name\` = \"PS_MAIL_SMTP_PORT\""
    fi

    if [ -f $targetFolder/bin/console ]; then
        hasClientCommand=`./bin/console | grep prestashop:api-client > /dev/null; echo $?`
        if [ "$hasClientCommand" = "0" ]; then
            echo Authorize Admin API in dev mode
            mysql -u root -D $targetDatabase -e "UPDATE \`ps_configuration\` SET \`value\` = \"0\" WHERE \`name\` = \"PS_ADMIN_API_FORCE_DEBUG_SECURED\""

            if [ "$apiClientId" != "" ] && [ "$apiClientSecret" != "" ]; then
                echo "Create default API client $apiClientId (apiClientId/apiClientSecret from config.yml)"
                $targetFolder/bin/console prestashop:api-client create $apiClientId --all-scopes --name='Test client' --description='Test client with all scopes' --timeout=3600 --secret=$apiClientSecret
            else
                echo "No apiClientId/apiClientSecret in config.yml, skipping API client creation"
            fi
        fi
    fi

    backup_data

    echo Warmup frontend cache
    curl $targetUrl 2> /dev/null > /dev/null

    echo Warmup backend cache
    pushd $BASEDIR
    npm run warmup-backoffice ${suffix}
    popd
}

clear_cache() {
    cd $targetFolder
    echo Removing cache files..
    rm -fR var/cache/*
    if test -f $targetFolder/app/config/parameters.php; then
        echo Clear cache without warmup...
        php -d memory_limit=-1 ./bin/console cache:clear --env=dev --no-warmup
        php -d memory_limit=-1 ./bin/console cache:clear --env=prod --no-warmup
    fi
}

backup_data() {
    echo Dump database $targetDatabase in $targetFolder/var/dump.sql
    mysqldump -u root $targetDatabase > $targetFolder/var/dump.sql
}

reset_data() {
    echo Drop database $targetDatabase
    mysql -u root -e "DROP DATABASE IF EXISTS \`$targetDatabase\`;"
    echo Create database $targetDatabase
    mysql -u root -e "CREATE DATABASE \`$targetDatabase\`;"
    echo Load dump from $targetFolder/var/dump.sql
    mysql -u root $targetDatabase < $targetFolder/var/dump.sql
    clear_cache
}

# Returns 0 if assets building is required
check_build_assets_required() {
    # No Makefile present, so no build possible
    if ! test -f $targetFolder/Makefile; then
        echo "No Makefile detected probably an old version that does not need assets building"
        return 1
    fi

    if ! test -f $targetFolder/tools/assets/build.sh; then
        echo "No build script found probably a built archive"
        return 1
    fi

    if ! test -d $targetFolder/admin-dev/themes/default/public; then
        echo "Admin default theme missing"
        return 0
    fi
    if ! test -d $targetFolder/admin-dev/themes/new-theme/public; then
        echo "Admin new theme missing"
        return 0
    fi
    if ! test -f $targetFolder/themes/core.js; then
        echo "Front core assets missing"
        return 0
    fi
    if ! test -f $targetFolder/themes/classic/assets/css/theme.css; then
        echo "Front classic theme stylesheet missing"
        return 0
    fi
    if ! test -f $targetFolder/themes/classic/assets/js/theme.js; then
        echo "Front classic theme js missing"
        return 0
    fi

    # All required assets have been checked so no build needed
    echo "All required assets are present"
    return 1
}

install_multi_shop_data() {
  cd $BASEDIR
  npm run install-multi-shop-data $targetUrl/admin-dev
}
# Prints the instance suffix when the given path is inside an instance folder
# (${baseFolder}<suffix> or any sub folder), prints nothing otherwise
detect_suffix_from_path() {
    case "$1" in
        "$baseFolder"*)
            candidate=${1#"$baseFolder"}
            echo "${candidate%%/*}"
            ;;
    esac
}

# Returns 0 when the database given as argument exists
db_exists() {
    found=$(mysql -u root -N -s -e "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = '$1'" 2>/dev/null)
    test "$found" != ""
}

# Prints the PrestaShop version of the project folder given as argument
get_ps_version() {
    if test -f "$1/install-dev/install_version.php"; then
        sed -n "s/.*_PS_INSTALL_VERSION_', *'\([^']*\)'.*/\1/p" "$1/install-dev/install_version.php" | head -n 1
    elif test -f "$1/install/install_version.php"; then
        sed -n "s/.*_PS_INSTALL_VERSION_', *'\([^']*\)'.*/\1/p" "$1/install/install_version.php" | head -n 1
    elif test -f "$1/config/settings.inc.php"; then
        sed -n "s/.*_PS_VERSION_', *'\([^']*\)'.*/\1/p" "$1/config/settings.inc.php" | head -n 1
    else
        echo "-"
    fi
}

# Returns 0 when the script is attached to a terminal (stdin may be a pipe, so stdout and stderr are checked too)
is_interactive() {
    [ -t 0 ] || [ -t 1 ] || [ -t 2 ]
}

# Runs a command with sudo, asking for the password only when needed.
# In a terminal this is a plain sudo (password asked in the terminal as usual).
# Without a terminal (script driven by an AI agent, a hook, ...) sudo cannot prompt, so the
# password is asked in a macOS dialog through tools/askpass.sh with a message telling which
# script needs it and why. On failure or cancel the command to run manually is printed and
# the sudo exit code is returned, the calling script decides what to do with it.
# Usage: run_sudo "reason" command [args...]
run_sudo() {
    reason=$1
    shift
    if is_interactive; then
        sudo "$@"
    else
        askpass="$(cd "$BASEDIR/tools" && pwd)/askpass.sh"
        SUDO_ASKPASS="$askpass" sudo -A -p "$(basename "$0") $suffix needs administrator rights to: $reason" "$@"
    fi
    sudoStatus=$?
    if [ $sudoStatus -ne 0 ]; then
        echo "sudo failed or was cancelled ($reason), run this manually: sudo $*" >&2
    fi
    return $sudoStatus
}
