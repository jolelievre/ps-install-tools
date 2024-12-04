module.exports.loginBO = async (page, config) => {
    await page.type('#email', config.email);
    await page.type('#passwd', config.password);
    await page.click('#submit_login');
    try {
        await page.waitForNavigation({waitUntil: 'load', timeout: 5000});
    } catch {
        // Do nothing we only wait for the load for old versions that are slower
    }
    // Wait for the BO menu to be visible
    await page.waitForSelector('.nav-bar:not(.mobile-nav)');
    console.log('Login to BO successful');
};
