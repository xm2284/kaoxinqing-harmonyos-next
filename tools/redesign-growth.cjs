const fs = require('fs');
const root = 'entry/src/main/ets/';
const read = p => fs.readFileSync(root+p, 'utf8');
const write = (p,s) => fs.writeFileSync(root+p,s);
let s=read('services/SettingsService.ets');
s=s.replace('  static async commonTools()', `  static async growthDemoEnabled(): Promise<boolean> {
    if (SettingsService.store === undefined) { return true; }
    return await SettingsService.store.get('growth_demo', true) as boolean;
  }
  static async saveGrowthDemo(enabled: boolean): Promise<void> {
    if (SettingsService.store === undefined) { throw new Error('设置尚未就绪'); }
    await SettingsService.store.put('growth_demo', enabled); await SettingsService.store.flush();
    AppStorage.setOrCreate('growthDemo', enabled);
  }

  static async commonTools()`);write('services/SettingsService.ets',s);
s=read('pages/MyPage.ets');
s=s.replace("import { router }", "import { GrowthDonut, GrowthTrend } from '../components/GrowthCharts';\nimport { DemoGrowthService, GrowthPoint } from '../services/DemoGrowthService';\nimport { router }");
s=s.replace("  @StorageLink('privacyMode')", "  @StorageLink('growthDemo') demo: boolean = true;\n  @State changingDemo: boolean = false;\n  @StorageLink('privacyMode')");
s=s.replace('      this.selectedTools = await SettingsService.commonTools();', '      this.demo = await SettingsService.growthDemoEnabled();\n      this.selectedTools = await SettingsService.commonTools();');
const badgeStart=s.indexOf('  private badges()'), badgeEnd=s.indexOf('  private distributionTotal()',badgeStart);
let badges=s.slice(badgeStart,badgeEnd).replaceAll('this.assessments.length','this.demo ? 7 : this.assessments.length').replaceAll('this.drawCount','this.demo ? DemoGrowthService.CARDS : this.drawCount').replaceAll('this.restCount','this.demo ? DemoGrowthService.RESTS : this.restCount').replaceAll('this.breathCount','this.demo ? DemoGrowthService.BREATHS : this.breathCount').replaceAll('this.challengeCount','this.demo ? DemoGrowthService.CHALLENGES : this.challengeCount').replaceAll('this.consecutiveDays','this.demo ? DemoGrowthService.DAYS : this.consecutiveDays').replaceAll('this.trainingCount','this.demo ? 13 : this.trainingCount');
s=s.slice(0,badgeStart)+badges+s.slice(badgeEnd);
s=s.replace('  private distributionTotal(): number { return Math.max(1, this.breathCount + this.restCount + this.challengeCount); }', `  private chartValues(): number[] { return this.demo ? [DemoGrowthService.BREATHS, DemoGrowthService.RESTS, DemoGrowthService.CHALLENGES] : [this.breathCount, this.restCount, this.challengeCount]; }
  private chartPoints(): GrowthPoint[] {
    if (this.demo) { return DemoGrowthService.points(); }
    return this.assessments.slice(0, 7).reverse().map((item: AssessmentRecord) => { return { label: item.date.substring(5, 10), value: item.stressLevel }; });
  }
  private async toggleDemo(): Promise<void> {
    if (this.changingDemo) { return; } this.changingDemo = true;
    try { await SettingsService.saveGrowthDemo(!this.demo); }
    catch (reason) { this.toast('展示模式未保存，请重试。'); }
    finally { this.changingDemo = false; }
  }
  private badgeColor(item: BadgeItem): string {
    return item.asset.includes('medal') ? '#AA7223' : (item.asset.includes('leaf') ? '#378B70' : (item.asset.includes('card') ? '#8762BC' : '#347EC0'));
  }
  private badgeBackground(item: BadgeItem): string {
    return item.asset.includes('medal') ? '#FFF4DB' : (item.asset.includes('leaf') ? '#E9F7EC' : (item.asset.includes('card') ? '#F2ECFF' : '#EAF5FF'));
  }`);
s=s.replace("this.Stat(this.assessments.length, '测评记录'); this.Stat(this.trainingCount, '调节练习')", "this.Stat(this.demo ? 7 : this.assessments.length, '测评记录'); this.Stat(this.demo ? 13 : this.trainingCount, '调节练习')");
s=s.replace("this.Stat(this.consecutiveDays, '连续陪伴'); this.Stat(this.minutes, '练习分钟')", "this.Stat(this.demo ? 7 : this.consecutiveDays, '连续陪伴'); this.Stat(this.demo ? 90 : this.minutes, '练习分钟')");
s=s.replace("          Divider().color('#EAF0F7')", "          if (this.demo) { Text('示例展示中 · 数据与勋章不计入真实成长').fontSize(11).fontColor('#9A6D2E').width('100%') }\n          Divider().color('#EAF0F7')");
let start=s.indexOf('  @Builder GrowthCard()'),end=s.indexOf('  @Builder Badge(',start);
s=s.slice(0,start)+`  @Builder GrowthCard() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 3 }) {
          Text('成长足迹').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#274362')
          Text(this.demo ? '一周示例 · 看见每一次小小进步' : '你的真实记录 · 每一小步都算数').fontSize(11).fontColor('#667B90')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button(this.demo ? '切换真实' : '看看示例').height(44).fontSize(11).fontColor('#3A6C90')
          .backgroundColor('#E8F1F7').enabled(!this.changingDemo).onClick(() => { this.toggleDemo(); })
      }.width('100%')
      Row({ space: 16 }) {
        GrowthDonut({ values: this.chartValues() })
        Column({ space: 14 }) {
          Text('我的调节方式').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#365873')
          this.ChartLegend('云息呼吸', this.chartValues()[0], '#4C90DF')
          this.ChartLegend('松风休息', this.chartValues()[1], '#4DAA8E')
          this.ChartLegend('认知重构', this.chartValues()[2], '#A280CC')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      Divider().color('#E3EDF3')
      Row() {
        Text('心情起伏').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#365873').layoutWeight(1)
        Text('最近 7 次 · 压力参考值').fontSize(10).fontColor('#667B90')
      }.width('100%')
      if (this.chartPoints().length > 0) { GrowthTrend({ points: this.chartPoints() }) }
      else { Text('还没有测评记录。完成一次测评后，再来看看自己的变化。').fontSize(12).fontColor('#667B90').padding(16) }
      Row() {
        Text(this.demo ? '示例数据不代表你的心理状态' : '起伏很正常，分数仅供自我了解').fontSize(10).fontColor('#667B90').layoutWeight(1)
        Button('全部记录').height(44).fontSize(12).backgroundColor(Color.Transparent).fontColor('#3578AD')
          .onClick(() => { this.open('pages/GrowthRecordsPage'); })
      }.width('100%')
    }.width('100%').padding(16).linearGradient({ angle: 135, colors: [['#FFFFFF', 0], ['#F1F8FC', 1]] })
      .border({ width: 1, color: '#DFEBF3' }).borderRadius(24)
  }
  @Builder ChartLegend(label: string, value: number, color: string) {
    Row({ space: 8 }) {
      Circle().width(7).height(7).fill(color)
      Text(label).fontSize(12).fontColor('#60758A').layoutWeight(1)
      Text(value.toString() + ' 次').fontSize(12).fontWeight(FontWeight.Medium).fontColor('#365873')
    }.width('100%')
  }
`+s.slice(end);
s=s.replace("Image($rawfile(item.asset)).width(40).height(40)", "Image($rawfile(item.asset.replace('.svg', '_color.svg'))).width(48).height(48)");
s=s.replace(".fontColor(item.value >= item.target ? UiTokens.TEXT_PRIMARY : '#778493')", ".fontColor(item.value >= item.target ? this.badgeColor(item) : '#778493')");
s=s.replace(".backgroundColor(item.value >= item.target ? '#EDF6FF' : '#F3F5F7')", ".backgroundColor(item.value >= item.target ? this.badgeBackground(item) : '#F3F5F7')");
s=s.replace("message: '解锁条件：'", "message: (this.demo ? '当前为示例勋章，切换真实后显示你的实际进度。\\n' : '') + '解锁条件：'");
write('pages/MyPage.ets',s);
s=read('pages/GrowthRecordsPage.ets');
s="import { DemoGrowthService, DemoGrowthRecord } from '../services/DemoGrowthService';\nimport { SettingsService } from '../services/SettingsService';\n"+s;
s=s.replace('  @State rows:', "  @StorageLink('growthDemo') @Watch('resetPage') demo: boolean = true;\n  @State changingDemo: boolean = false;\n  @State rows:");
s=s.replace('  private async load()', '  private resetPage(): void { this.page = 0; this.historyScroller.scrollEdge(Edge.Top); }\n  private async load()');
s=s.replace('      const cards:', '      this.demo = await SettingsService.growthDemoEnabled();\n      const cards:');
s=s.replace('return this.rows.filter', "return (this.demo ? DemoGrowthService.records().map((item: DemoGrowthRecord): HistoryItem => { return { key: item.key, kind: item.kind, title: item.title, text: item.text, date: item.date }; }) : this.rows).filter");
s=s.replace("      PageHeader({ title: '我的成长记录' })", `      PageHeader({ title: '我的成长记录' })
      Row({ space: 8 }) {
        Text(this.demo ? '示例记录 · 不计入真实成长' : '真实记录 · 来自你的使用').fontSize(12).fontColor('#86682E').layoutWeight(1)
        Button(this.demo ? '切换真实' : '看看示例').fontSize(12).height(44).enabled(!this.changingDemo)
          .onClick(async () => { this.changingDemo = true; try { await SettingsService.saveGrowthDemo(!this.demo); }
            catch (reason) { this.getUIContext().getPromptAction().showToast({ message: '切换失败，请重试。' }); }
            finally { this.changingDemo = false; } })
      }.width('100%').padding({ left: 16, right: 16 }).backgroundColor('#FFF9EC')`);
write('pages/GrowthRecordsPage.ets',s);
const shapes={
book:'<path d="M19 20c6-2 11-1 13 2 3-3 8-4 14-2v23c-6-2-11-1-14 2-3-3-7-4-13-2Z"/><path d="M32 23v21M23 27h4M37 27h5M23 33h4M37 33h5"/>',
leaf:'<path d="M46 18C25 16 17 25 21 36c7 11 25 3 25-18Z"/><path d="m18 46 22-22M28 36v-8M33 31h8"/>',
card:'<rect x="20" y="17" width="26" height="34" rx="5" transform="rotate(10 33 34)"/><path d="m33 24 3 6 6 1-5 5 1 6-5-3-6 3 1-6-4-5 6-1Z"/>',
medal:'<path d="m22 37-4 18 13-6 12 6-3-18"/><circle cx="31" cy="27" r="15"/><path d="m31 18 3 6 6 1-4 4 1 7-6-3-6 3 1-7-4-4 6-1Z"/>'};
const colors={book:['#82C7F8','#357FC7'],leaf:['#93D8AB','#39997D'],card:['#C6ACEF','#8862BD'],medal:['#F5D886','#D49A35']};
for(const key of Object.keys(shapes)) fs.writeFileSync('entry/src/main/resources/rawfile/badge_'+key+'_color.svg',`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><defs><linearGradient id="g" x2="1" y2="1"><stop stop-color="${colors[key][0]}"/><stop offset="1" stop-color="${colors[key][1]}"/></linearGradient></defs><circle cx="32" cy="32" r="30" fill="url(#g)"/><circle cx="32" cy="32" r="26" fill="none" stroke="#fff" stroke-opacity=".4"/><g fill="none" stroke="#fff" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round">${shapes[key]}</g></svg>`);
console.log('Growth preview, charts, records and colored badges updated.');
