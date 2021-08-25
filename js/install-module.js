if (process.argv.length < 4) {
  console.info('Usage: install-module.js back_office_url module_path');

  process.exit(1);
}
const yaml = require('js-yaml');
const fs   = require('fs');
const path   = require('path');
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
const modulePath = process.argv[3];
const moduleName = path.basename(modulePath, '.zip');

console.log('Install module from ' + moduleName + ' in PrestaShop ' + backOfficeUrl);

const run = async () => {
  const browser = await puppeteer.launch({
    headless: false,
    args: ['--no-sandbox'],
  });
  const page = await browser.newPage();

  // Login in BO
  console.log('Login in BO');
  await page.goto(backOfficeUrl, {waitUntil: 'networkidle0'});
  await tools.loginBO(page);
  const modulePageUrl = await page.evaluate(() => {
    return document.querySelector('#subtab-AdminModules a').href;
  });
  console.log('Go to modules page');
  //This call may be long if the shop has just been installed
  await page.goto(modulePageUrl, {waitUntil: 'load', timeout: 60000});
  await page.waitForSelector('#moduleQuicksearch');

  await page.type('#moduleQuicksearch', moduleName);
  await page.$('#moduleQuicksearch', moduleName);
  await page.waitFor(1000);

  const anchorSelector = '#module-list #anchor' + moduleName.charAt(0).toUpperCase() + moduleName.slice(1);
  console.log(anchorSelector);
  await page.waitForSelector(anchorSelector);
  const installUrl = await page.evaluate((anchorSelector) => {
    const anchor = document.querySelector(anchorSelector);
    const moduleLine = anchor.parentNode.parentNode;
    const installButton = moduleLine.querySelector('td.actions a.btn-success:first-child');

    return installButton ? installButton.href : null;
  }, anchorSelector);
  if (installUrl) {
    console.log('Install module via address '+installUrl);
    await page.goto(installUrl);
  } else {
    console.error('Could not find install button');
  }

  await browser.close();
};

run()
.then(() => {
  console.log('Module installed');
}).catch((e) => {
  console.error(`${e}`);
});
