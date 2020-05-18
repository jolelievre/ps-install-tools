module.exports.loginBO = async (page, config) => {
    await page.type('#email', config.email);
    await page.type('#passwd', config.password);
    await page.click('button[name="submitLogin"]');
    await page.waitForNavigation({waitUntil: 'domcontentloaded'});
    console.log('Login to BO successful');
};
