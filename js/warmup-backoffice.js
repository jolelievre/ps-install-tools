if (process.argv.length < 3) {
    console.info('Usage: warmup-backoffice.js suffix');

    process.exit(1);
}

const tools = require('./tools');
const config = require('./config');
const puppeteer = require('puppeteer');

const backOfficeUrl = 'http://' + config.domainPlaceholder.replace('{SUFFIX}', process.argv[2]) + '/admin-dev';

const run = async () => {
    const browser = await puppeteer.launch({
      headless: true,
      args: ['--no-sandbox'],
    });
    const page = await browser.newPage();
  
    // Login in BO
    console.log('Login in BO: ' + backOfficeUrl);
    await page.goto(backOfficeUrl, {waitUntil: 'networkidle0'});
    await tools.loginBO(page, config);
    await browser.close();
};

run()
.then(() => {
  console.log('Backoffice warmup done');
}).catch((e) => {
  console.error(`${e}`);
});
