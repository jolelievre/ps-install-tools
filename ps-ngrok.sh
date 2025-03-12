#!/bin/sh

BASEDIR=$(dirname "$0")
source $BASEDIR/tools/config.sh

vhostFilePath="/opt/homebrew/etc/httpd/extra/sites-available/$targetDomain.conf"
if [ ! -f $vhostFilePath ]; then
    echo Could not find vhost file $vhostFilePath
    exit 1
fi

process=`ps aux | grep 'ngrok http' | grep -v 'grep'`
if [ "$process" != "" ]; then
    currentNgrokUrl=`echo $process | sed -n 's/\(.*\)ngrok http \(.*\) --log\(.*\)/\2/p'`
    ngrokPid=`echo $process | sed -nr "s_[^0-9]*([0-9]+)(.*)_\1_p"`
    echo One ngrok already running for $currentNgrokUrl, killing process $ngrokPid
    kill -9 $ngrokPid
    # Sleep to wait for the tunnel to be closed
    sleep 1
fi

echo Cleaning logs
ngrokLog=$targetFolder/var/logs/ngrok.log
ngrokErrorLog=$targetFolder/var/logs/ngrok.error.log
rm -f $ngrokLog
rm -f $ngrokErrorLog

echo Launching ngrok
ngrok http $targetUrl --log=$ngrokLog 2> $ngrokErrorLog > /dev/null &

echo Waiting for ngrok log file
until [ -e $ngrokLog ]; do sleep 1; done

echo Wait for initialization
sleep 5
ngrokUrl=`cat $ngrokLog | grep "started tunnel" | sed -n 's/\(.*\)url=\(.*\)/\2/p'`
if [ "$ngrokUrl" = "" ]; then
    echo Wait for initialization
    sleep 5
    ngrokUrl=`cat $ngrokLog | grep "started tunnel" | sed -n 's/\(.*\)url=\(.*\)/\2/p'`
fi

if [ "$ngrokUrl" = "" ]; then
    echo Could not find ngrok url check the logs to see what happened
    echo
    cat $ngrokLog
    echo
    cat $ngrokErrorLog
    exit 1
fi

ngrokDomain=`echo $ngrokUrl | sed "s_http[s]*\://__"`
echo Updating vhost configuration $vhostFilePath with domain $ngrokDomain
newVhostFile=`cat $vhostFilePath | sed -r "s_(.*)ServerAlias \".*\"_\1ServerAlias \"$ngrokDomain\"_g" | sed -r "s_(.*)ServerName \".*\"_\1ServerName \"$ngrokDomain\"_g"`
echo "$newVhostFile" > $vhostFilePath

# Replace default local host, or previous ngrok domain already present
echo Updating shop Htaccess file
newHtaccess=`cat $targetFolder/.htaccess | sed "s@$targetDomain@$ngrokDomain@g" | sed -r "s@\^.*ngrok-free\.app@\^$ngrokDomain@g"`
echo "$newHtaccess" > $targetFolder/.htaccess

echo Update environment trusted proxies
newEnv=`cat $targetFolder/.env | sed -r "s@PS_TRUSTED_PROXIES=.*@PS_TRUSTED_PROXIES=127.0.0.1,REMOTE_ADDR@g"`
echo "$newEnv" > $targetFolder/.env

echo Updating shop URL in DB
mysql -u root -D $targetDatabase -e "UPDATE \`ps_configuration\` SET \`value\` = \"$ngrokDomain\" WHERE \`name\` = \"PS_SHOP_DOMAIN\""
mysql -u root -D $targetDatabase -e "UPDATE \`ps_configuration\` SET \`value\` = \"$ngrokDomain\" WHERE \`name\` = \"PS_SHOP_DOMAIN_SSL\""
mysql -u root -D $targetDatabase -e "UPDATE \`ps_configuration\` SET \`value\` = \"1\" WHERE \`name\` = \"PS_SSL_ENABLED\""
mysql -u root -D $targetDatabase -e "UPDATE \`ps_shop_url\` SET \`domain\` = \"$ngrokDomain\", \`domain_ssl\` = \"$ngrokDomain\""

echo Stoping apache
sudo brew services stop httpd

echo Clear shop cache
rm -fR $targetFolder/var/cache/*

echo Restarting apache
sudo brew services start httpd

echo
echo You can now access your shop to this address:
echo $ngrokUrl
echo $ngrokUrl/admin-dev
