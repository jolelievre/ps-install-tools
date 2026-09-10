#!/bin/sh
#
# Usage: ps-install-classic <suffix> [version]
#
# Builds the PrestaShop Classic Edition <version> with the smb_edition_builder project
# (config _dev/classic-config/<editionLocale>/config_classic_<version>.yml), uninstalls the
# instance <suffix> when it already exists (in the background while the build runs, a build
# cannot be replaced in place), moves the built release to the instance folder and installs
# it with ps-install.
#
# When <version> is missing or has no config file, a menu of the available versions (newest
# first) is shown in the terminal; without a terminal the versions are listed and the script
# aborts.
#
# The builder folder, locale, Addons credentials and GitHub token come from config.yml
# (editionBuilderFolder, editionLocale, addonsUserAgent, addonsUser, addonsPassword,
# githubToken, githubEmail, githubName), so no secret is typed on the command line.

usage() {
    echo "Command usage:"
    echo
    echo "ps-install-classic <suffix> [version]"
    echo
    echo "ps-install-classic classic                 Pick the version in a menu and install it as the 'classic' instance"
    echo "ps-install-classic classic 9.2.x           Build config_classic_9.2.x.yml and install it as the 'classic' instance"
    echo "ps-install-classic classic-828 8.2.8       Build config_classic_8.2.8.yml and install it as the 'classic-828' instance"
    echo "ps-install-classic classic-91 9.1.5-5.0    Build config_classic_9.1.5-5.0.yml and install it as the 'classic-91' instance"
}

fail() {
    echo "$1" >&2
    exit 1
}

if test $# -lt 1 || test $# -gt 2; then
    usage >&2
    exit 1
fi

echo "Installing a new local PrestaShop Classic Edition instance"
echo

# Absolute path: the script changes directory to the builder folder before calling its siblings
BASEDIR=$(cd "$(dirname "$0")" && pwd)
source $BASEDIR/tools/config.sh
version=$2

## Checks before anything is touched
if test "$editionBuilderFolder" = "" || ! test -f "$editionBuilderFolder/bin/console"; then
    fail "Edition builder not found in '$editionBuilderFolder': editionBuilderFolder in $BASEDIR/config.yml must point to a clone of smb_edition_builder"
fi
if ! test -d "$editionBuilderFolder/vendor"; then
    fail "No vendor folder in $editionBuilderFolder, run composer install there first"
fi

configFolder="$editionBuilderFolder/_dev/classic-config/$editionLocale"
# Reverse alphabetical order puts the newest versions first
availableVersions=$(ls "$configFolder"/config_classic_*.yml 2>/dev/null | sed 's/.*config_classic_//; s/\.yml$//' | sort -r)
if test "$availableVersions" = ""; then
    fail "No config_classic_*.yml found in $configFolder"
fi

configFile="$configFolder/config_classic_$version.yml"
if test "$version" = "" || ! test -f "$configFile"; then
    if test "$version" != ""; then
        echo "No config found for Classic Edition version '$version' in $configFolder" >&2
    fi
    echo
    # select_option (tools/tools.sh) draws the menu when a terminal is available
    version=$(select_option "Which Classic Edition version do you want to build?" $availableVersions)
    selectStatus=$?
    if test $selectStatus = 1; then
        fail "No version selected, aborting"
    elif test $selectStatus != 0; then
        echo "Available versions in $configFolder (pass one as second argument):" >&2
        echo $availableVersions >&2
        exit 1
    fi
    echo "Selected version: $version"
    configFile="$configFolder/config_classic_$version.yml"
fi

for configKey in addonsUserAgent addonsUser addonsPassword githubToken; do
    eval configValue=\$$configKey
    if test "$configValue" = ""; then
        fail "$configKey is empty in $BASEDIR/config.yml, fill it before building the Classic Edition"
    fi
done

# Git identity used by the builder to fetch corp modules: config.yml, then the git config,
# then the builder defaults when both are empty
if test "$githubEmail" = ""; then
    githubEmail=$(git config --get user.email 2>/dev/null)
fi
if test "$githubName" = ""; then
    githubName=$(git config --get user.name 2>/dev/null)
fi

# An instance matches the suffix when any of its elements is left
enabledVhostFilePath="/opt/homebrew/etc/httpd/extra/sites-enabled/$targetDomain.conf"
instanceExists=0
if test -d "$targetFolder" || db_exists "$targetDatabase" || test -f "$enabledVhostFilePath"; then
    instanceExists=1
fi

releaseFolder="$editionBuilderFolder/workdir/tools/build/releases/prestashop"

echo
echo "Edition builder:    $editionBuilderFolder"
echo "Build config:       $configFile"
echo "Release folder:     $releaseFolder"
echo "Git identity:       ${githubEmail:-builder default} / ${githubName:-builder default}"
echo
if test $instanceExists = 1; then
    echo "WARNING: an instance already matches the suffix $suffix, it will be uninstalled"
    echo "(folder, databases, vhost, hosts entry) in the background while the build runs."
else
    echo "No existing instance matches the suffix $suffix, nothing to uninstall."
fi
echo
read -n 1 -p "Do you confirm build and installation? [Y/n] " confirm

if test "$confirm" = "n"; then
    exit 1
else
    if test "$confirm" = "N"; then
        exit 1
    fi
fi
echo

stepsIndex=1
stepsNb=5

## 1- Uninstall the existing instance in the background
uninstallPid=""
uninstallLog=""
if test $instanceExists = 1; then
    echo "$stepsIndex / $stepsNb: Uninstalling the existing instance $suffix in the background"
    # Validate sudo now: the background uninstall has no terminal, with a cached ticket its
    # Apache restarts and /etc/hosts edit do not need to ask for the password again
    run_sudo "cache administrator rights for the background uninstall of $suffix" -v
    if test $? -ne 0; then
        fail "Could not get administrator rights, aborting before touching anything"
    fi
    uninstallLog="$tmpFolder/ps-install-classic-$suffix-uninstall.log"
    echo Y | $BASEDIR/ps-uninstall.sh $suffix > "$uninstallLog" 2>&1 &
    uninstallPid=$!
    echo "Uninstall running (pid $uninstallPid), log: $uninstallLog"
else
    echo "$stepsIndex / $stepsNb: No existing instance $suffix to uninstall"
fi
stepsIndex=$(($stepsIndex+1))
echo

## 2- Build the release
echo "$stepsIndex / $stepsNb: Building Classic Edition $version in $editionBuilderFolder/workdir"
cd "$editionBuilderFolder"
if test -d workdir; then
    echo "Removing previous build in workdir"
    rm -fR workdir 2>/dev/null
    if test -d workdir; then
        # Docker builds leave files owned by root
        run_sudo "remove the previous build in $editionBuilderFolder/workdir" rm -fR workdir
    fi
fi
mkdir -p workdir

set -- -c "$configFile" -A "$addonsUserAgent" -u "$addonsUser:$addonsPassword" -t "$githubToken"
if test "$githubEmail" != ""; then
    set -- "$@" -E "$githubEmail"
fi
if test "$githubName" != ""; then
    set -- "$@" -N "$githubName"
fi
set -- "$@" --no-zip --keep-tests

echo "Command used: php bin/console prestashop:edition:build -c \"$configFile\" -A \"$addonsUserAgent\" -u \"$addonsUser:***\" -t \"***\" -E \"$githubEmail\" -N \"$githubName\" --no-zip --keep-tests"
php bin/console prestashop:edition:build "$@"
buildStatus=$?
stepsIndex=$(($stepsIndex+1))
echo

## 3- Wait for the uninstall (always, even after a failed build, so Apache is never left stopped)
if test "$uninstallPid" != ""; then
    echo "$stepsIndex / $stepsNb: Waiting for the uninstall of $suffix to finish"
    wait $uninstallPid
    uninstallStatus=$?
    if test $uninstallStatus -ne 0 || test -d "$targetFolder"; then
        echo "Uninstall of $suffix failed (status $uninstallStatus), last lines of $uninstallLog:" >&2
        tail -n 20 "$uninstallLog" >&2
        if test $buildStatus = 0; then
            echo "The build is available in $releaseFolder" >&2
        fi
        exit 1
    fi
    echo "Instance $suffix uninstalled, see $uninstallLog"
else
    echo "$stepsIndex / $stepsNb: No uninstall to wait for"
fi
stepsIndex=$(($stepsIndex+1))
echo

if test $buildStatus -ne 0; then
    fail "Build failed with status $buildStatus, aborting"
fi
if ! test -d "$releaseFolder"; then
    fail "Build finished but the release folder $releaseFolder is missing, aborting"
fi

## 4- Move the build to the instance folder
echo "$stepsIndex / $stepsNb: Moving the release to $targetFolder"
mv "$releaseFolder" "$targetFolder" || fail "Could not move the release to $targetFolder"
for folder in admin install; do
    if test -d "$targetFolder/$folder" && ! test -d "$targetFolder/$folder-dev"; then
        echo "Renaming $folder to $folder-dev"
        mv "$targetFolder/$folder" "$targetFolder/$folder-dev"
    fi
done
stepsIndex=$(($stepsIndex+1))
echo

## 5- Install the instance (its own confirmation is covered by the one above)
echo "$stepsIndex / $stepsNb: Installing the instance $suffix with ps-install"
echo Y | $BASEDIR/ps-install.sh $suffix
