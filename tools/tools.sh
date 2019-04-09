#!/bin/sh

insert_data() {
    echo Dropping database..
    mysql -u root -e "DROP DATABASE IF EXISTS \`$targetDatabase\`;"
    cd $targetFolder
    echo Removing cache files..
    rm -fR var/cache/*
    echo Inserting fixtures data...
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
        --email=jonathan.lelievre@prestashop.com \
        --password=prestashop
}
