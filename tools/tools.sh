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
        echo "You need to update your config first:"
        echo
    fi
    read -p "$configName [$defaultValue]: " userValue
    if test "x$userValue" = "x"; then
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
    echo Dropping database $targetDatabase...
    mysql -u root -e "DROP DATABASE IF EXISTS \`$targetDatabase\`;"
    cd $targetFolder
    echo Removing cache files..
    rm -fR var/cache/*
    echo "Inserting fixtures data for domain $targetDomain database $targetDatabase..."
    php install-dev/index_cli.php \
        --language=en \
        --country=fr \
        --domain=$targetDomain \
        --base_uri=/ \
        --db_server=127.0.0.1 \
        --db_user=root \
        --db_name=$targetDatabase \
        --db_create=1 \
        --firstname=Jo \
        --lastname=LELIEVRE \
        --name="$targetName" \
        --email=$email \
        --password=$password
    if [ "x$smtpUser" != "x" ] && [ "x$smtpPass" != "x" ]; then
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
}
