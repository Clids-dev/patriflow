const sass = require('sass');
const path = require('path');
const fs = require('fs');
const out = process.argv[2];
const res = sass.compile(path.join(__dirname, 'scss/app.scss'), {
  style: 'compressed',
  loadPaths: [path.join(__dirname, 'node_modules')],
  quietDeps: true,
  logger: sass.Logger.silent,
});
fs.writeFileSync(out, res.css);
console.log('bytes', res.css.length);
