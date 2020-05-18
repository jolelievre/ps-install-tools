const yaml = require('js-yaml');
const fs   = require('fs');

// Get document, or throw exception on error
try {
    var config = yaml.safeLoad(fs.readFileSync(__dirname + '/../config.yml', 'utf8'));
} catch (e) {
    console.error(e);
  
    process.exit(1);
}

module.exports = config;
