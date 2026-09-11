const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const ets = path.join(root, 'entry/src/main/ets');
const raw = path.join(root, 'entry/src/main/resources/rawfile');
const routes = JSON.parse(fs.readFileSync(path.join(root, 'entry/src/main/resources/base/profile/main_pages.json'), 'utf8')).src;
const pages = ['HomeContent', 'AdjustPage', 'MyPage', 'GamePage', 'RestBreakPage', 'AppSettingsPage', 'HelpPage', 'SupportPage', 'GrowthRecordsPage', 'CountdownSettingPage'];
let assets = 0, links = 0;
for (const route of routes) assert.ok(fs.existsSync(path.join(ets, route + '.ets')), 'Missing route: ' + route);
for (const page of pages) {
  const code = fs.readFileSync(path.join(ets, 'pages', page + '.ets'), 'utf8');
  for (const match of code.matchAll(/\$rawfile\(['"]([^'"]+)['"]\)/g)) {
    assert.ok(fs.existsSync(path.join(raw, match[1])), page + ': missing asset ' + match[1]); assets++;
  }
  for (const match of code.matchAll(/['"](pages\/[A-Za-z]+)['"]/g)) {
    assert.ok(routes.includes(match[1]), page + ': unregistered route ' + match[1]); links++;
  }
}
for (const page of ['GamePage', 'RestBreakPage']) {
  const code = fs.readFileSync(path.join(ets, 'pages', page + '.ets'), 'utf8');
  assert.ok(!/GameBottomNav|RestBottomNavigation|AppBottomNavigation/.test(code), page + ': duplicate navigation');
}
for (const id of ['BV12r4y157pt', 'BV1Sh4y1d7yE', 'BV1oB4y1B73S', 'BV1so4y1C7dY', 'BV1GK4y1W7ek', 'BV1iW411w7Fn']) {
  assert.ok(fs.statSync(path.join(raw, 'bili_' + id + '.jpg')).size > 1000, id + ': missing cover');
}
for (const name of ['ocean', 'rain', 'forest']) {
  const wav = fs.readFileSync(path.join(raw, 'ambient_' + name + '.wav'));
  assert.equal(wav.toString('ascii', 0, 4), 'RIFF');
  assert.equal(wav.toString('ascii', 8, 12), 'WAVE');
  assert.equal(wav.readUInt32LE(24), 24000);
  assert.equal(wav.readUInt32LE(40), 60 * 24000 * 2);
}
const report = `PASS: ${routes.length} registered pages, ${links} navigation references, ${assets} literal assets, 6 corresponding Bilibili covers, 3 complete 60-second WAV files, no nested bottom navigation.\n`;
fs.writeFileSync(path.join(root, 'verification/ui-links-results.txt'), report);
process.stdout.write(report);
