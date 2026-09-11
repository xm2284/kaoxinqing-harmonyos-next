// Execute production ArkTS services after TypeScript erasure, against real SQLite.
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('node:assert/strict');
const { DatabaseSync } = require('node:sqlite');
const ts = require('D:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js');
const root = path.resolve('entry/src/main/ets');
const cache = new Map();
let sqlite = new DatabaseSync(':memory:');
let failInsert = false;
class Predicates {
  constructor(table) { this.table = table; this.where = []; this.args = []; this.order = ''; }
  equalTo(key,value) {this.where.push(`${key} = ?`);this.args.push(value);return this;}
  orderByAsc(key){this.order=` ORDER BY ${key} ASC`;return this;}
  orderByDesc(key){this.order=` ORDER BY ${key} DESC`;return this;}
}
class Result {
  constructor(rows){this.rows=rows;this.rowCount=rows.length;this.index=-1;}
  goToNextRow(){return ++this.index<this.rows.length;}
  goToFirstRow(){this.index=0;return this.rows.length>0;}
  getColumnIndex(key){return key;}
  getString(key){return String(this.rows[this.index][key]);}
  getLong(key){return Number(this.rows[this.index][key]);}
  getDouble(key){return Number(this.rows[this.index][key]);}
  close(){}
}
const store={
  async executeSql(sql,args=[]){sqlite.prepare(sql).run(...args);},
  async query(p){return new Result(sqlite.prepare(`SELECT * FROM ${p.table}${p.where.length?' WHERE '+p.where.join(' AND '):''}${p.order}`).all(...p.args));},
  async insert(table,values){
    if(failInsert&&table==='card_deck_seen')throw new Error('injected disk failure');
    const keys=Object.keys(values);return Number(sqlite.prepare(`INSERT INTO ${table} (${keys.join(',')}) VALUES (${keys.map(()=>'?').join(',')})`).run(...Object.values(values)).lastInsertRowid);
  },
  async update(values,p){const keys=Object.keys(values);return sqlite.prepare(`UPDATE ${p.table} SET ${keys.map(k=>k+'=?').join(',')} WHERE ${p.where.join(' AND ')}`).run(...Object.values(values),...p.args).changes;},
  async delete(p){return sqlite.prepare(`DELETE FROM ${p.table} WHERE ${p.where.join(' AND ')}`).run(...p.args).changes;},
  beginTransaction(){sqlite.exec('BEGIN');},commit(){sqlite.exec('COMMIT');},rollBack(){sqlite.exec('ROLLBACK');}
};
const memory=new Map();
const AppStorage={get:k=>memory.get(k),setOrCreate:(k,v)=>memory.set(k,v)};
function load(file){
  const full=path.resolve(root,file.endsWith('.ets')?file:file+'.ets');
  if(cache.has(full))return cache.get(full).exports;
  const module={exports:{}};cache.set(full,module);
  const source=fs.readFileSync(full,'utf8');
  const output=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2021}}).outputText;
  const requireLocal=name=>name==='@kit.ArkData'?{relationalStore:{RdbPredicates:Predicates,SecurityLevel:{S1:1},getRdbStore:async()=>store}}:
    name.startsWith('@kit.')?{}:load(path.relative(root,path.resolve(path.dirname(full),name)));
  vm.runInNewContext(output,{module,exports:module.exports,require:requireLocal,AppStorage,console,Date,Math,Set,Number,JSON,Error},{filename:full});
  return module.exports;
}
(async()=>{
  const {AppConstants}=load('common/DataModels');
  const {DatabaseService:DB}=load('services/DatabaseService');
  sqlite.exec('CREATE TABLE daily_quotes (id INTEGER PRIMARY KEY AUTOINCREMENT, content TEXT NOT NULL, category TEXT NOT NULL, used INTEGER NOT NULL, date TEXT)');
  for(const q of AppConstants.QUOTE_SEEDS.slice(62))await store.insert('daily_quotes',{content:q.content,category:q.category,used:1,date:'2026-09-01'});
  await store.insert('daily_quotes',{content:'用户自留的一句话',category:'自定义',used:1,date:'2026-09-02'});
  await DB.initDB({});
  assert.equal((await DB.getAllDailyQuotes()).length,127);
  assert.equal((await DB.getAllDailyQuotes()).filter(q=>q.used).length,65);
  DB.store=undefined;await DB.initDB({});
  assert.equal((await DB.getAllDailyQuotes()).length,127,'restart must not duplicate quote seeds');
  let previous=[];const seen=new Set();
  for(let n=0;n<21;n++){
    const batch=await DB.drawQuoteBatch(previous);
    assert.equal(batch.length,6);assert.equal(new Set(batch.map(q=>q.content)).size,6);
    for(const q of batch){assert(!seen.has(q.content),'repeat before exhaustion');seen.add(q.content);}
    previous=batch;
    DB.store=undefined;await DB.initDB({});
  }
  const next=await DB.drawQuoteBatch();
  assert(next.some(q=>!seen.has(q.content)),'remaining unseen quote must be delivered at cycle rollover');
  assert(next.every(q=>!previous.some(p=>p.content===q.content)),'cycle boundary must avoid last displayed six after restart');
  const before=sqlite.prepare('SELECT count(*) n FROM card_deck_seen').get().n;
  failInsert=true;await assert.rejects(DB.drawQuoteBatch(next));failInsert=false;
  assert.equal(sqlite.prepare('SELECT count(*) n FROM card_deck_seen').get().n,before,'failed reservation must rollback');
  await DB.addCardDraw(next[0]);DB.store=undefined;await DB.initDB({});
  assert.equal((await DB.getCardDraws())[0].content,next[0].content);
  await DB.addFeedback('功能建议','测试反馈仅保存在内存数据库');assert.equal((await DB.getFeedback()).length,1);
  const exam={name:'期末考试',date:'2026-12-20',subjects:['数学'],createdAt:'2026-09-01'};
  exam.id=await DB.addExamInfo(exam);exam.name='资格考试';await DB.updateExamInfo(exam);
  assert.equal((await DB.getAllExamInfo())[0].name,'资格考试');await DB.deleteExamInfo(exam.id);assert.equal((await DB.getAllExamInfo()).length,0);
  console.log('PASS database upgrade, idempotency, 126 unique draws across restarts, cycle rollover, rollback, card history, feedback, exam CRUD');
  const {SafetyGuardService:S}=load('services/SafetyGuardService');
  const high=['我想自杀','我不想活了','我想伤害自己','自 杀','想\u200b死','我想自殺','I want to kill myself','I don’t want to live','活着没意义','我吃了一把药','我研究自杀，也想死','我不想死但是活不下去'];
  for(const text of high)assert.equal(S.check(text).riskLevel,'high',text);
  const normal=['笑死我了','累死了今天','这场考试是生死战','作业太多了','今天很开心'];
  for(const text of normal)assert.equal(S.check(text).riskLevel,'normal',text);
  for(const text of ['自杀预防是什么','我不想死，我只是很累','我撑不住了'])assert.equal(S.check(text).riskLevel,'support',text);
  const crisis=[{role:'user',content:'我想死'},{role:'assistant',content:'先确保安全'},{role:'user',content:'嗯'}];
  assert(S.checkConversation(crisis).shouldStopModel);
  assert(S.checkConversation(crisis.concat([{role:'user',content:'没有人陪着我'}])).shouldStopModel);
  assert(!S.checkConversation(crisis.concat([{role:'user',content:'我现在安全，家人正陪着我'}])).shouldStopModel);
  const {TinglanAgentService:T}=load('services/TinglanAgentService');
  const convo=[];const replies=[];
  for(let n=0;n<5;n++){convo.push({role:'user',content:'我担心考试成绩'});const r=T.localReply(convo);assert(!replies.includes(r));replies.push(r);convo.push({role:'assistant',content:r});}
  assert(T.localReply([{role:'user',content:'你好'}]).length>4);
  assert(T.localReply(crisis).includes('12356'));
  assert(T.localReply([{role:'user',content:'胸闷心跳很快'}]).match(/就医|医疗|陪/));
  const {AdaptiveLayout:A}=load('common/AdaptiveLayout');
  const today=new Date();const local=`${today.getFullYear()}-${String(today.getMonth()+1).padStart(2,'0')}-${String(today.getDate()).padStart(2,'0')}`;
  assert.equal(A.daysUntil(local),0);assert.equal(A.daysUntil('bad'),0);
  console.log('PASS crisis variants, negation, harmless phrases, multi-turn safety, local reply diversity, medical symptom caution, local calendar');
  fs.writeFileSync('verification/domain-results.txt','PASS: database migration and preservation; 126 unique draws; restart and cycle handling; rollback; record persistence; feedback; exam CRUD; crisis and false-positive cases; local reply diversity; local dates.\n');
})().catch(error=>{console.error(error);process.exitCode=1;});
