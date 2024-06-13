module.exports.loginBO = async (page, config) => {
    await page.type('#email', config.email);
    await page.type('#passwd', config.password);
    await page.click('#submit_login');
    await page.waitForSelector('body.ps_back-office');
    await page.waitForNavigation({waitUntil: 'load'});
    console.log('Login to BO successful');
};
