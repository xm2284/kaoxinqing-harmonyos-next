const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const root = path.resolve('entry/src/main/ets');
const files = [];
function walk(folder) {
  for (const name of fs.readdirSync(folder)) {
    const full = path.join(folder, name);
    const stat = fs.statSync(full);
    if (stat.isDirectory()) walk(full);
    else if (name.endsWith('.ets')) files.push(full);
  }
}
walk(root);
const source = files.map(file => fs.readFileSync(file, 'utf8')).join('\n');
assert.ok(!/\brouter\.(pushUrl|back|getParams)\s*\(/.test(source), 'legacy global router call remains');
assert.ok(!/(?<![.\w])animateTo\s*\(/.test(source), 'legacy global animateTo call remains');
assert.ok(!/\bgetContext\s*\(\s*this\s*\)/.test(source), 'legacy global getContext call remains');
assert.ok(!/\.write\s*\(\s*buffer\s*\)/.test(source), 'deprecated AudioRenderer.write call remains');
assert.ok(source.includes('.getUIContext().getRouter().pushUrl('), 'UIContext router migration missing');
assert.ok(source.includes(".on('writeData',"), 'AudioRenderer writeData migration missing');
console.log(`PASS: ${files.length} ArkTS files use UIContext routing/animation/context and event-based AudioRenderer output.`);
