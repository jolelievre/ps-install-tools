if (process.argv.length < 3) {
  console.info('Usage: launch-upgrade.js back_office_url');

  process.exit(1);
}
const yaml = require('js-yaml');
const fs   = require('fs');
const puppeteer = require('puppeteer');
 
// Get document, or throw exception on error
try {
  var config = yaml.safeLoad(fs.readFileSync(__dirname + '/../config.yml', 'utf8'));
} catch (e) {
  console.log(e);

  process.exit(1);
}

const backOfficeUrl = process.argv[2];

console.log('Launch upgrade in PrestaShop ' + backOfficeUrl);

const loginBO = async (page) => {
  await page.type('#email', config.email);
  await page.type('#passwd', config.password);
  //Use Promise.all to avoid promise race and miss the waitForNavigation
  await Promise.all([
    page.waitForNavigation({waitUntil: 'domcontentloaded'}),
    page.click('button[name="submitLogin"]'),
  ]);
};

const run = async () => {
  const browser = await puppeteer.launch({
    headless: false,
    args: ['--no-sandbox'],
  });
  const page = await browser.newPage();
  page.setViewport({
    width: 1024,
    height: 1024,
    deviceScaleFactor: 1,
  });

  // Login in BO
  console.log('Login in BO');
  await page.goto(backOfficeUrl, {waitUntil: 'networkidle0'});
  await loginBO(page);
  
  const upgradePageUrl = await page.evaluate(() => {
    return document.querySelector('#subtab-AdminSelfUpgrade a').href;
  });
  console.log('Go to upgrade module', upgradePageUrl);
  await page.goto(upgradePageUrl, {waitUntil: 'load', timeout: 60000});

  const maintenanceButton = await page.evaluate(() => {
    return document.querySelector('input[name="putUnderMaintenance"]');
  });
  if (maintenanceButton) {
    console.log('Put shop on maintenance mode');
    //Use Promise.all to avoid promise race and miss the waitForNavigation
    await Promise.all([
      page.waitForNavigation({waitUntil: 'domcontentloaded'}),
      page.click('input[name="putUnderMaintenance"]'),
    ]);
  }

  console.log('Check that target is major');
  try {
    await page.waitForSelector('#channel');
  } catch (e) {
    console.log('Channel hidden, expand expert mode');
    await page.click('input[name="btn_adv"]');
    await page.waitForSelector('#channel');
  }

  const selectedChannel = await page.evaluate(() => {
    const selector = document.querySelector('#channel');

    return selector.options[selector.selectedIndex].value;
  });
  if (selectedChannel != 'major') {
    console.log('Select upgrade to major version');
    await page.focus('#channel');
    await page.select('#channel', 'major');
    await page.waitForSelector('input[name="submitConf-channel"]');
    //Use Promise.all to avoid promise race and miss the waitForNavigation
    await Promise.all([
      page.waitForNavigation({waitUntil: 'domcontentloaded'}),
      page.click('input[name="submitConf-channel"]'),
    ]);
  }

  console.log('Start upgrade, keep the browser open');
  await page.waitForSelector('#upgradeNow');
  await page.focus('#upgradeNow');
  await page.click('#upgradeNow');
  await page.waitForSelector('#currentlyProcessing');
  await page.focus('#currentlyProcessing');

  console.log('Your shop is upgrading...');
  //Wait for 15 minutes
  await page.waitForSelector('#upgradeResultCheck[style=""]', {timeout: 15 * 60 * 1000});
  const upgradeResult = await page.evaluate(() => {
    const notification = document.querySelector('#upgradeResultCheck');

    return notification.textContent;
  });
  console.log('Upgrade result: '+upgradeResult);
  
  await browser.close();
};

run()
.then(() => {
  console.log('Your shop upgrade is over');
}).catch((e) => {
  console.error(`${e}`);
});
