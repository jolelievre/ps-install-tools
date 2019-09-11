#!/bin/sh

BASEDIR=$(dirname "$0")
source $BASEDIR/tools/config.sh

echo "Upgrading PrestaShop $suffix"
echo

cd $BASEDIR
npm run launch-upgrade $targetUrl/admin-dev
