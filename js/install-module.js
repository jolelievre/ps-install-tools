if (process.argv.length < 4) {
  console.info('Usage: install-module.js back_office_url module_path');

  process.exit(1);
}
const yaml = require('js-yaml');
const fs   = require('fs');
const path   = require('path');
const puppeteer = require('puppeteer');
 
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
console.log(config.email, config.password);

console.log('Install module from ' + moduleName + ' in PrestaShop ' + backOfficeUrl);

const loginBO = async (page) => {
  await page.type('#email', config.email);
  await page.type('#passwd', config.password);
  await page.click('button[name="submitLogin"]');
  await page.waitForNavigation({waitUntil: 'domcontentloaded'});
};

const run = async () => {
  const browser = await puppeteer.launch({
    headless: false,
    args: ['--no-sandbox'],
  });
  const page = await browser.newPage();

  // Login in BO
  console.log('Login in BO');
  await page.goto(backOfficeUrl, {waitUntil: 'networkidle0'});
  await loginBO(page);
  const modulePageUrl = await page.evaluate(() => {
    return document.querySelector('#subtab-AdminModules a').href;
  });
  console.log('Go to modules page');
  await page.goto(modulePageUrl);
  page.click('#desc-module-new');
  await page.waitForSelector('#file-name');
  await page.focus('#file-name');
  
  console.log('Upload module archive');
  const input = await page.$('input[type="file"]');
  await input.uploadFile(modulePath);
  await page.click('button[name="download"]');

  await page.waitForSelector('.bootstrap .alert');
  const successMessage = await page.evaluate(() => {
    return document.querySelector('.bootstrap .alert').textContent;
  });
  console.log(successMessage);
  await page.waitForSelector('#moduleQuicksearch');

  await page.type('#moduleQuicksearch', moduleName);
  await page.$('#moduleQuicksearch', moduleName);

  console.log('Click on install button');
  const installButton = '#module-list tr:first-child td.actions a.btn-success:first-child';
  await page.waitForSelector(installButton);
  await page.click(installButton);

  await browser.close();
};

run()
.then(() => {
  console.log('Module installed');
}).catch((e) => {
  console.error(`${e}`);
});
