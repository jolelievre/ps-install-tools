#!/bin/sh

echo "Installing a new local prestashop instance"
echo

BASEDIR=$(dirname "$0")
source $BASEDIR/tools/config.sh

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
    # Get PrestaShop cloned in temporary folder
    tmpPrestaShopFolder="$tmpFolder/PrestaShop"
    if ! test -d $tmpPrestaShopFolder; then
        echo "Cloning repository $forkedGithub into $tmpPrestaShopFolder"
        cd $tmpFolder
        git clone $forkedGithub PrestaShop
        cd $tmpPrestaShopFolder
        git remote add upstream $upstreamGithub
    else
        echo "Temporary backup of PrestaShop was found in $tmpPrestaShopFolder, no need to clone it"
    fi

    # Update the backup repository and copy it to target folder
    echo "Updating PrestaShop folder"
    cd $tmpPrestaShopFolder
    git fetch upstream
    git fetch origin

    echo "Copying PrestaShop repository into $targetFolder"
    cp -R $tmpPrestaShopFolder $targetFolder

    parentFolder=$(dirname $targetFolder)
    cloneFolder=$(basename $targetFolder)

    cd $targetFolder
    # Select the branch to start from
    if test $# -gt 1; then
        branch=$2
        echo "$stepsIndex-b / $stepsNb: Selecting the branch $branch as a starting point"
    else
        availableBranches=`git branch -a | grep remotes/upstream | sed s_remotes/upstream/__ | sed s_\ __g`
        forkBranches=`git branch -a | grep remotes/origin | sed s_remotes/origin/__ | sed s_\ __g`
        echo "$stepsIndex-b / $stepsNb: Selecting the branch you want to start from (default: develop)"
        echo "Available upstream branches:"
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

# No composer is for 1.6 version where modules are installed thanks to git submodules
if ! test -f composer.json; then
    echo "Install git submodules"
    git submodule init
    git submodule update
else
    php -d memory_limit=-1 `which composer` install
fi
stepsIndex=$(($stepsIndex+1))
echo

# 3- Prepare apache config
echo "$stepsIndex / $stepsNb: Prepare apache vhost"
vhostFilePath="/usr/local/etc/httpd/extra/sites-available/$targetDomain.conf"
if test -f $vhostFilePath; then
    echo "Vhost config is already available"
else
    baseLog="$HOME/www/var/logs/prestashop-"
    echo "Setting vhost config in $vhostFilePath:"
    cat > $vhostFilePath <<- EOM
<VirtualHost *:80>
    ServerAdmin ${email}
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

# 4- Updating /etc/hosts
hostEnabled=$(cat /etc/hosts | grep $targetDomain)

if test "x" = "x$hostEnabled"; then
    echo "$stepsIndex / $stepsNb: Updating /etc/hosts file"
    echo "127.0.0.1       $targetDomain" | sudo tee -a /etc/hosts
else
    echo "$stepsIndex / $stepsNb: Domain is already present in /etc/hosts"
fi
stepsIndex=$(($stepsIndex+1))
echo

# 5- Insert data in database (this step must be done once the site is accessible via apache because some url calls are made during install)
echo "$stepsIndex / $stepsNb: Install default PrestashopData in database: $targetDatabase"
insert_data

stepsIndex=$(($stepsIndex+1))
echo


echo
echo "Your Prestashop was installed at:"
echo $targetFolder
echo
echo "Your Prestashop instance is available at the following address:"
echo $targetUrl
echo $targetUrl/admin-dev
echo
