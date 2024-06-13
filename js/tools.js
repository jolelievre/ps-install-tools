module.exports.loginBO = async (page, config) => {
    await page.type('#email', config.email);
    await page.type('#passwd', config.password);
    await page.click('#submit_login');
    try {
        await page.waitForNavigation({waitUntil: 'load', timeout: 5000});
    } catch {
        // Do nothing we only wait for the load for old versions that are slower
    }
    await page.waitForSelector('body.ps_back-office');
    console.log('Login to BO successful');
};
