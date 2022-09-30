#!/bin/sh

echo "Installing a new local prestashop instance"
echo

BASEDIR=$(dirname "$0")
source $BASEDIR/tools/config.sh

echo "Upstream repository: $upstreamGithub"
echo "Origin repository: $originGithub"

contributor=''
branch=''
if test $# -gt 1; then
    if [[ $2 == *":"* ]]; then
        IFS=':'
        read -a branches <<< "$2"
        contributor=${branches[0]}
        contributorGithub="git@github.com:$contributor/PrestaShop.git"
        IFS=' '

        # If the contributor matches the origin repository we use origin as the contributor
        if test "$contributorGithub" = "$originGithub"; then
            contributor='origin'
        fi
        branch=${branches[1]}
    else
        branch=$2
    fi
    echo "Working branch: $branch"
fi

if ! test "$contributorGithub" = ""; then
    echo "Contributor: $contributor"
    echo "Contributor repository: $contributorGithub"
fi

echo
read -n 1 -p "Do you confirm installation? [Y/n] " confirm

if test "$confirm" = "n"; then
    exit 1
else
    if test "$confirm" = "N"; then
        exit 1
    fi
fi
echo

## Start installation
stepsIndex=1
stepsNb=5

## 1- Clone project if the folder does not exist
if test -d $targetFolder; then
    firstInstall=1
    echo "$stepsIndex-a / $stepsNb: Folder $targetFolder already exists, no need to create it"
    stepsIndex=$(($stepsIndex+1))
else
    firstInstall=0
    echo "$stepsIndex-a / $stepsNb: Prepare folder project in $targetFolder"
    # Get PrestaShop cloned in temporary folder
    tmpPrestaShopFolder="$tmpFolder/PrestaShop"

    # Check that folder exists AND composer file is there (tmp folder may be incompletely cleared and only keep a hidden .git folder)
    if ! [ -d $tmpPrestaShopFolder ] || ! [ -f "$tmpPrestaShopFolder/composer.json" ]; then
        echo "Cleaning tmp folder $tmpPrestaShopFolder"
        rm -fR $tmpPrestaShopFolder
        echo "Cloning repository $originGithub into $tmpPrestaShopFolder"
        cd $tmpFolder
        git clone $originGithub PrestaShop
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

    echo "Link default branch to upstream and update branch"
    git checkout develop
    git branch --set-upstream-to=upstream/develop
    git pull

    echo "Copying PrestaShop repository into $targetFolder"
    cp -R $tmpPrestaShopFolder $targetFolder

    cd $targetFolder
    # Select the branch to start from
    if test "$branch" = ""; then
        availableBranches=`git branch -a | grep remotes/upstream | sed s_remotes/upstream/__ | sed s_\ __g`
        forkBranches=`git branch -a | grep remotes/origin | sed s_remotes/origin/__ | sed s_\ __g`
        echo "$stepsIndex-b / $stepsNb: Selecting the branch you want to start from (default: develop)"
        echo "Available upstream branches:"
        echo $availableBranches
        echo

        read -p "Which branch do you wish to start from? [develop] " branch
        # Empty value is default value which is develop
        if test "$branch" = ""; then
            branch="develop"
        fi
    else
        echo "$stepsIndex-b / $stepsNb: Selecting the branch $branch as the working branch"
    fi
fi


cd $targetFolder
# Check if contributor repository is used
if ! test "$contributor" = ""; then
    git remote -v | grep "$contributorGithub" > /dev/null
    if ! test $? = 0; then
        echo "Add new remote repository $contributorGithub"
        git remote add $contributor $contributorGithub
        git fetch $contributor
    fi
fi

# Create the appropriate branch if it is not here yet
if [ "$branch" != "develop" ] && [ "$branch" != "" ]; then
    # To avoid less pagination
    export PAGER='less -FRSX'
    git branch -l | grep "$branch" > /dev/null
    if ! test $? = 0; then
        remoteRepository='upstream'
        if ! test "$contributor" = ""; then
            remoteRepository=$contributor
        fi

        echo "Checkout branch: $remoteRepository/$branch"
        git fetch $remoteRepository
        git checkout -b $branch $remoteRepository/$branch
    else
        echo "Branch $branch already exists locally"
        currentBranch=`git branch --show-current`
        if test "$currentBranch" = "$branch"; then
            echo "Already using branch $branch"
        else
            echo "Switching to branch $branch"
            git checkout $branch
        fi
    fi
else
    currentBranch=`git branch --show-current`
    echo "Keep using local branch $currentBranch"
fi
echo
stepsIndex=$(($stepsIndex+1))

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
check_build_assets_required
if test $? = 0; then
    echo "Build assets"
    make assets
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

if test "" = "$hostEnabled"; then
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

if test $firstInstall = 1; then
    echo "Switch to new freshly installed project $targetFolder"
    cd $targetFolder
    echo
fi
