#!/bin/sh

BASEDIR=$(dirname "$0")
source $BASEDIR/tools/config.sh
source $BASEDIR/tools/tools.sh

if test $# -gt 1; then
    echo "Branch starting point: $2"
fi
echo
read -n 1 -p "Do you confirm installation? [Y/n] " confirm

if test "x$confirm" = "xn"; then
    exit 1
else
    if test "x$confirm" = "xN"; then
        exit 1
    fi
fi
echo

## Start installation
stepsIndex=1
stepsNb=5

## 1- Clone project if the folder does not exist
if test -d $targetFolder; then
    echo "$stepsIndex / $stepsNb: Folder $targetFolder already exists, no need to create it"
    stepsIndex=$(($stepsIndex+1))
else
    echo "$stepsIndex-a / $stepsNb: Prepare folder project in $targetFolder"
    echo "Cloning $forkedGithub into $targetFolder"
    parentFolder=$(dirname $targetFolder)
    cloneFolder=$(basename $targetFolder)
    cd $parentFolder
    git clone $forkedGithub $cloneFolder
    cd $targetFolder
    git remote add upstream $upstreamGithub
    git fetch upstream

    # Select the branch to start from
    if test $# -gt 1; then
        branch=$2
        echo "$stepsIndex-b / $stepsNb: Selecting the branch $branch as a starting point"
    else
        availableBranches=`git branch -a | grep remotes/upstream | sed s_remotes/upstream/__ | sed s_\ __g`
        echo "$stepsIndex-b / $stepsNb: Selecting the branch you want to start from (default: develop)"
        echo "Available branches:"
        echo $availableBranches
        echo

        read -p "Which branch do you wish to start from? [develop] " branch
    fi
    if test "x$branch" = "x"; then
        branch="develop"
    fi

    echo "Selected branch: $branch"
    if test "$branch" = "develop"; then
        git branch --set-upstream-to=upstream/$branch
    else
        git checkout -b $branch upstream/$branch
    fi
    git pull
    echo
    stepsIndex=$(($stepsIndex+1))
fi
echo

# 2- Run composer install
echo "$stepsIndex / $stepsNb: Install vendors"
cd $targetFolder
php -d memory_limit=-1 `which composer` install
stepsIndex=$(($stepsIndex+1))
echo

# 3- Insert data in database
echo "$stepsIndex / $stepsNb: Install default PrestashopData in database: $targetDatabase"
insert_data

stepsIndex=$(($stepsIndex+1))
echo

# 4- Prepare apache config
echo "$stepsIndex / $stepsNb: Prepare apache vhost"
vhostFilePath="/usr/local/etc/httpd/extra/sites-available/$targetDomain.conf"
if test -f $vhostFilePath; then
    echo "Vhost config is already available"
else
    baseLog="/Users/jLelievre/www/var/logs/prestashop-"
    echo "Setting vhost config in $vhostFilePath:"
    cat > $vhostFilePath <<- EOM
<VirtualHost *:80>
    ServerAdmin jonathan.lelievre@prestashop.com
    DocumentRoot "${targetFolder}"
    ServerName "${targetDomain}"
    ServerAlias "${targetDomain}"
    ErrorLog "${baseLog}${suffix}.error.log"
    CustomLog "${baseLog}${suffix}.access.log" common
</VirtualHost>
EOM
    echo
    cat $vhostFilePath
    echo
fi

enabledVhostFilePath="/usr/local/etc/httpd/extra/sites-enabled/$targetDomain.conf"
if test -f $enabledVhostFilePath; then
    echo "Vhost config is already enabled"
else
    echo "Enabling vhost config"
    cd /usr/local/etc/httpd/extra/sites-enabled
    ln -s ../sites-available/$targetDomain.conf $targetDomain.conf

    echo "Restarting apache"
    sudo apachectl -k stop
    sleep 2
    sudo apachectl start
fi
stepsIndex=$(($stepsIndex+1))
echo


# 5- Updating /etc/hosts
hostEnabled=$(cat /etc/hosts | grep $targetDomain)

if test "x" = "x$hostEnabled"; then
    echo "$stepsIndex / $stepsNb: Updating /etc/hosts file"
    echo "127.0.0.1       $targetDomain" | sudo tee -a /etc/hosts
else
    echo "$stepsIndex / $stepsNb: Domain is already present in /etc/hosts"
fi

echo
echo "Your Prestashop instance is available at the following address:"
echo $targetUrl
