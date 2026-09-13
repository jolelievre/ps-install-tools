#!/bin/sh

if [ -z $BASEDIR ]; then
    BASEDIR=$(dirname "$0")/..
fi
source $BASEDIR/tools/tools.sh

load_config

if test $# -gt 0; then
    suffix=$1
else
    # Detect the instance from the current folder when it is inside an instance folder
    suffix=$(detect_suffix_from_path "$PWD")
    if test "$suffix" != ""; then
        if test "$quietInfos" != "1"; then
            echo "Detected instance from current folder: $suffix"
            echo
        fi
    else
        echo "Command usage:"
        echo
        echo "ps-install                                    Will ask to specify suffix and branch parameters interatively"
        echo "ps-install develop                            Use develop suffix"
        echo "ps-install 178 1.7.8.x                        Use 178 suffix and updtream branch 1.7.8.x"
        echo "ps-install feature jolelievre:feature-branch  Use the repository from use jolelievre with its branch feature-branch"
        echo "ps-install-classic classic 9.2.x              Build the Classic Edition 9.2.x with smb_edition_builder and install it as classic"
        echo
        echo "Enter a suffix for your installation which will define the folder, local domain and name of your shop"
        echo "Example: suffix = module => folder = ${baseFolder}module, domain = ${baseDomain}module"
        echo
        read -p "Suffix: " suffix
        echo
    fi
fi

# Without a terminal (AI agent, hook, cron) read returns an empty value: never go on with an empty suffix
if test "$suffix" = ""; then
    echo "No suffix given and none detected from the current folder, aborting" >&2
    exit 1
fi

set_target_instance "$suffix"

# Set quietInfos=1 before sourcing this file to skip the summary (ps-infos --json)
if test "$quietInfos" != "1"; then
    echo "These are the $suffix instance informations:"
    echo "Project folder:     $targetFolder"
    echo "Project url:        $targetUrl"
    echo "Project admin url:  $targetUrl/admin-dev"
    echo "Database name:      $targetDatabase"
fi
