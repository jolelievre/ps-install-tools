if (process.argv.length < 3) {
    console.info('Usage: install-multi-shop.js back_office_url');

    process.exit(1);
}

const yaml = require('js-yaml');
const fs   = require('fs');
const puppeteer = require('puppeteer');
const tools = require('./tools');

// Get document, or throw exception on error
try {
    var config = yaml.safeLoad(fs.readFileSync(__dirname + '/../config.yml', 'utf8'));
} catch (e) {
    console.log(e);

    process.exit(1);
}

const backOfficeUrl = process.argv[2];

console.log('Install multi shop data in PrestaShop ' + backOfficeUrl);

const enabledMultiShop = async (page) => {
    console.log('Enable multi shop mode');
    const preferencesUrl = await page.evaluate(() => {
        return document.querySelector('#subtab-AdminParentPreferences a').href;
    });

    //This call may be long if the shop has just been installed
    await page.goto(preferencesUrl, {waitUntil: 'load', timeout: 60000});
    await page.waitForSelector('#form_multishop_feature_active_1');

    const isChecked = await page.evaluate(() => {
        const checkbox = document.querySelector('#form_multishop_feature_active_1');

        return checkbox.checked;
    });

    if (!isChecked) {
        await page.click('#form_multishop_feature_active_1');
        await page.click('#form-preferences-save-button');
        await page.waitForSelector('div.alert.alert-success');
    } else {
        console.log('Multistore mode already enabled');
    }
}

const createShopGroup = async (page, shopGroupName) => {
    console.log(`Add new shop group "${shopGroupName}"`);
    const shopGroupUrl = await page.evaluate(() => {
        return document.querySelector('#subtab-AdminShopGroup a').href;
    });
    await page.goto(shopGroupUrl);
    const groupExists = await searchForGroupShop(page, shopGroupName);

    if (!groupExists) {
        await page.click('#page-header-desc-shop_group-new');
        await page.waitForSelector('#shop_group_form');
        await page.type('#name', shopGroupName);
        await page.click('#share_customer_on');
        await page.click('#share_stock_on');
        await page.click('#share_order_on');
        await page.click('#shop_group_form_submit_btn');
        await page.waitForSelector('div.alert.alert-success');
    } else {
        console.log(`Shop group "${shopGroupName}" already exists`);
    }
}

const searchForGroupShop = async (page, shopGroupName) => {
    return await page.evaluate((shopGroupName) => {
        const nameColumns = document.querySelectorAll('.column-name');

        let matchesName = false;
        nameColumns.forEach((column) => {
            if (column.textContent.trim() === shopGroupName) {
                matchesName = true;
            }
        })

        return matchesName;
    }, shopGroupName);
}

const createShop = async (page, shopName, shopGroupId, shopColor) => {
    console.log(`Add new shop "${shopName}"`);
    const shopGroupUrl = await page.evaluate(() => {
        return document.querySelector('#subtab-AdminShopGroup a').href;
    });
    await page.goto(shopGroupUrl);
    const shopExists = await searchForShop(page, shopName);

    if (!shopExists) {
        await page.click('#page-header-desc-shop_group-new_2');
        await page.waitForSelector('#shop_form');
        await page.type('#name', shopName);
        await page.select('#id_shop_group', shopGroupId);
        await page.type('#color_0', shopColor);

        await page.click('#shop_form_submit_btn');
        await page.waitForSelector('div.alert.alert-success');
    } else {
        console.log(`Shop "${shopName}" already exists`);
    }
}

const searchForShop = async (page, shopName) => {
    return await page.evaluate((shopName) => {
        const nameItems = document.querySelectorAll('.tree-item-name');

        let matchesName = false;
        nameItems.forEach((treeItem) => {
            if (treeItem.textContent.trim() === shopName) {
                matchesName = true;
            }
        })

        return matchesName;
    }, shopName);
}

const run = async () => {
    const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox'],
    });
    const page = await browser.newPage();

    // This is to allow using console log inside evaluate callback functions
    // page.on('console', consoleObj => console.log(consoleObj.text()));

    // Login in BO
    console.log('Login in BO');
    await page.goto(backOfficeUrl, {waitUntil: 'networkidle0'});
    await tools.loginBO(page, config);

    await enabledMultiShop(page);

    await createShopGroup(page, 'Shop Group 2');

    await createShop(page, 'Shop 2', '1', '#008542');
    await createShop(page, 'Shop 3', '2', '#ffe000');
    await createShop(page, 'Shop 4', '2', '#e70001');

    await browser.close();
};

run()
    .then(() => {
        console.log('Multi shop data installed');
    }).catch((e) => {
    console.error(`${e}`);
});