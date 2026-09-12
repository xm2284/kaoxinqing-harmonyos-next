const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require('D:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js');

const root = path.resolve('entry/src/main/ets');
const cache = new Map();
function load(file) {
  const full = path.resolve(root, file.endsWith('.ets') ? file : file + '.ets');
  if (cache.has(full)) return cache.get(full).exports;
  const module = { exports: {} };
  cache.set(full, module);
  const source = fs.readFileSync(full, 'utf8');
  const output = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021 }
  }).outputText;
  const localRequire = name => load(path.relative(root, path.resolve(path.dirname(full), name)));
  vm.runInNewContext(output, { module, exports: module.exports, require: localRequire, Math, Date }, { filename: full });
  return module.exports;
}

const { MentalHealthAnalyzer } = load('services/MentalHealthAnalyzer');
const at = index => `2026-09-${String(10 - index).padStart(2, '0')}T10:00:00.000Z`;
const record = (index, score, factors = []) => ({
  recordedAt: at(index), moodScore: score, moodLabel: '', emotions: [], factors, note: '', source: 'daily'
});

assert.equal(MentalHealthAnalyzer.analyze([]).trackedDays, 0);
const rising = [record(0, 8, ['睡眠']), record(1, 8, ['睡眠']), record(2, 7), record(3, 4), record(4, 4), record(5, 3)];
assert.equal(MentalHealthAnalyzer.analyze(rising).title, '状态正在回升');
assert.equal(MentalHealthAnalyzer.analyze(rising).topFactor, '睡眠');
const low = [record(0, 2), record(1, 3), record(2, 2), record(3, 4)];
assert.equal(MentalHealthAnalyzer.analyze(low).attention, true);

const page = fs.readFileSync(path.join(root, 'pages/MentalHealthPage.ets'), 'utf8');
for (const text of ['记录此刻', '心情趋势', '本地轻分析', '专业量表', '查看心理支持']) {
  assert.ok(page.includes(text), `missing UI flow: ${text}`);
}
console.log('PASS: mental-health empty, rising, factor and attention rules; record, trend, analysis, assessment and support UI flows.');
