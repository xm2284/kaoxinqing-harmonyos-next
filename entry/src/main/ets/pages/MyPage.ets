import { GrowthDonut, GrowthTrend } from '../components/GrowthCharts';
import { DemoGrowthService, GrowthPoint } from '../services/DemoGrowthService';
import { AppUsage, AssessmentRecord, CardDrawRecord, ChatMessage, ExamInfo, MentalHealthRecord, ThoughtChallenge, TrainingRecord, UserProfile } from '../common/DataModels';
import { AdaptiveLayout } from '../common/AdaptiveLayout';
import { UiTokens } from '../common/UiTokens';
import { DatabaseService } from '../services/DatabaseService';
import { SettingsService } from '../services/SettingsService';

interface MyTool { key: string; name: string; asset: string; route: string; }
interface BadgeItem { name: string; value: number; target: number; unit: string; asset: string; }

@Component
export struct MyPage {
  @StorageLink('growthDemo') demo: boolean = true;
  @State changingDemo: boolean = false;
  @StorageLink('privacyMode') privacyMode: boolean = false;
  @StorageLink('dataRefreshVersion') @Watch('refresh') refreshVersion: number = 0;
  @StorageLink('expandBadges') expandBadges: boolean = false;
  @State profile: UserProfile = { nickname: '同学', grade: '', school: '' };
  @State exam: ExamInfo = { name: '', date: '', subjects: [] };
  @State assessments: AssessmentRecord[] = [];
  @State mentalRecords: MentalHealthRecord[] = [];
  @State trainingCount: number = 0;
  @State challengeCount: number = 0;
  @State drawCount: number = 0;
  @State chatCount: number = 0;
  @State consecutiveDays: number = 0;
  @State minutes: number = 0;
  @State breathCount: number = 0;
  @State restCount: number = 0;
  @State selectedTools: string[] = ['mental', 'breath', 'chat', 'rest'];
  @State draftTools: string[] = [];
  @State editingTools: boolean = false;
  @State savingTools: boolean = false;
  @State sheetMode: string = 'tools';
  @State failed: boolean = false;
  private badgeScroller: Scroller = new Scroller();
  private readonly tools: MyTool[] = [
    { key: 'mental', name: '心理状态', asset: 'kxq_extra_heartbeat.png', route: 'pages/MentalHealthPage' },
    { key: 'breath', name: '云息呼吸', asset: 'kxq_adjust_breath_feature.png', route: 'pages/RelaxationPage' },
    { key: 'game', name: '心晴游戏坊', asset: 'kxq_adjust_game_feature.png', route: 'pages/GamePage' },
    { key: 'chat', name: '听澜心语', asset: 'kxq_ip_sleepy_chat.png', route: 'pages/CognitivePage' },
    { key: 'rest', name: '松风休息站', asset: 'kxq_scene_rest_lake_bench_wide.png', route: 'pages/RestBreakPage' },
    { key: 'records', name: '我的记录', asset: 'badge_book.svg', route: 'pages/GrowthRecordsPage' },
    { key: 'badges', name: '成就勋章', asset: 'badge_medal.svg', route: 'badges' }
  ];
  aboutToAppear(): void { this.load(); }
  private refresh(): void { this.load(); }
  private async load(): Promise<void> {
    try {
      const profiles: UserProfile[] = await DatabaseService.getAllUserProfiles();
      if (profiles.length > 0) { this.profile = profiles[0]; }
      const exams: ExamInfo[] = await DatabaseService.getAllExamInfo();
      this.exam = exams.length > 0 ? exams[0] : { name: '', date: '', subjects: [] };
      this.assessments = await DatabaseService.getAllAssessments();
      this.mentalRecords = await DatabaseService.getMentalHealthRecords();
      const trainings: TrainingRecord[] = await DatabaseService.getAllTrainingRecords();
      const challenges: ThoughtChallenge[] = await DatabaseService.getAllThoughtChallenges();
      const cards: CardDrawRecord[] = await DatabaseService.getCardDraws();
      const messages: ChatMessage[] = await DatabaseService.getAllChatMessages();
      const usage: AppUsage[] = await DatabaseService.getAllAppUsage();
      this.trainingCount = trainings.length; this.challengeCount = challenges.length; this.drawCount = cards.length;
      this.chatCount = messages.filter((item: ChatMessage) => item.role === 'user').length;
      this.consecutiveDays = usage.length > 0 ? usage[0].consecutiveDays : 0;
      this.minutes = Math.round(trainings.reduce((sum: number, item: TrainingRecord) => sum + item.duration, 0) / 60);
      this.restCount = trainings.filter((item: TrainingRecord) => item.type.includes('rest') || item.type.includes('休息')).length;
      this.breathCount = trainings.length - this.restCount;
      this.demo = await SettingsService.growthDemoEnabled();
      this.selectedTools = await SettingsService.commonTools(); this.failed = false;
    } catch (reason) { this.failed = true; }
  }
  private open(route: string): void {
    if (route === 'badges') { this.sheetMode = 'badges'; this.editingTools = true; return; }
    this.getUIContext().getRouter().pushUrl({ url: route }).catch(() => { this.toast('页面暂时没有打开，请重试。'); });
  }
  private toast(message: string): void { this.getUIContext().getPromptAction().showToast({ message: message }); }
  private commonTools(): MyTool[] { return this.tools.filter((item: MyTool) => this.selectedTools.indexOf(item.key) >= 0); }
  private editTools(): void { this.sheetMode = 'tools'; this.draftTools = this.selectedTools.slice(); this.editingTools = true; }
  private toggleTool(key: string): void {
    if (this.draftTools.indexOf(key) >= 0) { this.draftTools = this.draftTools.filter((item: string) => item !== key); }
    else if (this.draftTools.length < 4) { this.draftTools = this.draftTools.concat([key]); }
    else { this.draftTools = this.draftTools.slice(); this.toast('常用工具最多选 4 个。'); }
  }
  private async saveTools(): Promise<void> {
    if (this.draftTools.length === 0) { this.toast('至少选择一个常用工具。'); return; }
    this.savingTools = true;
    try { await SettingsService.saveCommonTools(this.draftTools); this.selectedTools = this.draftTools.slice(); this.editingTools = false; }
    catch (reason) { this.toast('没有保存成功，选择已保留。'); }
    finally { this.savingTools = false; }
  }
  private badges(): BadgeItem[] {
    return [
      { name: '初识自己', value: this.demo ? 7 : this.mentalRecords.length + this.assessments.length, target: 1, unit: '次心理记录', asset: 'badge_book.svg' },
      { name: '翻开心晴', value: this.demo ? DemoGrowthService.CARDS : this.drawCount, target: 6, unit: '张翻卡', asset: 'badge_card.svg' },
      { name: '认真休息', value: this.demo ? DemoGrowthService.RESTS : this.restCount, target: 1, unit: '次休息', asset: 'badge_leaf.svg' },
      { name: '自在呼吸', value: this.demo ? DemoGrowthService.BREATHS : this.breathCount, target: 3, unit: '次呼吸', asset: 'badge_leaf.svg' },
      { name: '换个角度', value: this.demo ? DemoGrowthService.CHALLENGES : this.challengeCount, target: 3, unit: '次重构', asset: 'badge_book.svg' },
      { name: '一周陪伴', value: this.demo ? DemoGrowthService.DAYS : this.consecutiveDays, target: 7, unit: '天连续使用', asset: 'badge_medal.svg' },
      { name: '心晴收藏家', value: this.demo ? DemoGrowthService.CARDS : this.drawCount, target: 30, unit: '张翻卡', asset: 'badge_card.svg' },
      { name: '坚持练习', value: this.demo ? 13 : this.trainingCount, target: 10, unit: '次调节', asset: 'badge_medal.svg' },
      { name: '慢慢生长', value: this.demo ? DemoGrowthService.DAYS : this.consecutiveDays, target: 30, unit: '天连续使用', asset: 'badge_leaf.svg' }
    ];
  }
  private chartValues(): number[] { return this.demo ? [DemoGrowthService.BREATHS, DemoGrowthService.RESTS, DemoGrowthService.CHALLENGES] : [this.breathCount, this.restCount, this.challengeCount]; }
  private chartPoints(): GrowthPoint[] {
    if (this.demo) { return DemoGrowthService.points(); }
    return this.assessments.slice(0, 7).reverse().map((item: AssessmentRecord) => { return { label: item.date.substring(5, 10), value: item.stressLevel } as GrowthPoint; });
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
  }
  build() {
    Scroll(this.badgeScroller) {
      Column({ space: 16 }) {
        Row() {
          Column({ space: 4 }) {
            Text('我的').fontSize(24).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
            Text('把每一点成长留给自己').fontSize(12).fontColor(UiTokens.TEXT_SECONDARY)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Button({ type: ButtonType.Circle }) {
            Image($rawfile('kxq_ui_settings_glass.png')).width(26).height(26).objectFit(ImageFit.Contain)
          }.width(44).height(44).backgroundColor(Color.White).accessibilityText('设置与个人资料')
            .onClick(() => { this.open('pages/AppSettingsPage'); })
        }.width('100%')
        if (this.failed) { Button('数据未加载完整，点此重试').height(44).onClick(() => { this.load(); }) }
        Column({ space: 14 }) {
          Row({ space: 12 }) {
            Image($rawfile('kxq_ip_sitting.png')).width(64).height(64).objectFit(ImageFit.Contain)
            Column({ space: 6 }) {
              Text(this.privacyMode ? '同学' : this.profile.nickname).fontSize(20).fontWeight(FontWeight.Bold).maxLines(1)
              Text(this.privacyMode ? this.profile.grade : [this.profile.grade, this.profile.school].filter((s: string) => s.length > 0).join(' · '))
                .fontSize(12).fontColor(UiTokens.TEXT_SECONDARY).maxLines(1)
              Text('编辑个人资料').fontSize(12).fontColor(UiTokens.PRIMARY)
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.width('100%').onClick(() => { this.open('pages/AppSettingsPage'); })
          if (this.demo) { Text('示例展示中 · 数据与勋章不计入真实成长').fontSize(11).fontColor('#9A6D2E').width('100%') }
          Divider().color('#EAF0F7')
          Row() {
            this.Stat(this.demo ? 7 : this.mentalRecords.length, '心情记录'); this.Stat(this.demo ? 13 : this.trainingCount, '调节练习')
            this.Stat(this.demo ? 7 : this.consecutiveDays, '连续陪伴'); this.Stat(this.demo ? 90 : this.minutes, '练习分钟')
          }.width('100%')
        }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(22)
        Column({ space: 8 }) {
          Row() {
            Text('我的工具').fontSize(17).fontWeight(FontWeight.Bold).layoutWeight(1)
            Button('编辑常用').height(44).fontSize(12).backgroundColor(Color.Transparent).fontColor(UiTokens.PRIMARY)
              .onClick(() => { this.editTools(); })
          }.width('100%')
          Row() {
            ForEach(this.commonTools(), (item: MyTool) => {
              Column({ space: 8 }) {
                Image($rawfile(item.asset)).width(44).height(44).objectFit(ImageFit.Contain)
                Text(item.name).fontSize(11).fontColor(UiTokens.TEXT_PRIMARY).maxLines(1)
              }.layoutWeight(1).height(80).justifyContent(FlexAlign.Center).onClick(() => { this.open(item.route); })
            }, (item: MyTool) => item.key)
          }.width('100%')
        }.width('100%').padding({ left: 12, right: 12, bottom: 12 }).backgroundColor(Color.White).borderRadius(22)
        this.GrowthCard()
        Column({ space: 12 }) {
          Row() {
            Text('成就勋章').fontSize(17).fontWeight(FontWeight.Bold).layoutWeight(1)
            Button(this.expandBadges ? '收起' : '全部 9 枚').height(44).fontSize(12).fontColor(UiTokens.PRIMARY)
              .backgroundColor(Color.Transparent).onClick(() => { this.expandBadges = !this.expandBadges; })
          }.width('100%')
          ForEach(this.expandBadges ? [0, 1, 2] : [0, 1], (row: number) => {
            Row({ space: 8 }) {
              ForEach(this.badges().slice(row * 3, row * 3 + 3), (item: BadgeItem) => { this.Badge(item) })
            }.width('100%')
          })
          Text('彩色为已点亮，灰色为待解锁；点按查看条件。').fontSize(11).fontColor(UiTokens.TEXT_SECONDARY)
        }.width('100%').padding(14).backgroundColor(Color.White).borderRadius(22)
        Column() {
          this.LinkRow('心理状态', '日常心情、影响因素与持续趋势', 'pages/MentalHealthPage')
          this.LinkRow('目标与计划', this.exam.name.length > 0 ? this.exam.name + ' · 距考试 ' + AdaptiveLayout.daysUntil(this.exam.date).toString() + ' 天' : '设置考试日期与复习科目', 'pages/CountdownSettingPage')
          this.LinkRow('我的记录', '翻卡、调节、重构与测评都在这里', 'pages/GrowthRecordsPage')
          this.LinkRow('考后分析', '记录各科成绩与变化', 'pages/AnalysisPage')
          this.LinkRow('帮助与反馈', '常见问题和本机反馈记录', 'pages/HelpPage')
        }.width('100%').padding({ left: 16, right: 16 }).backgroundColor(Color.White).borderRadius(22)
        Button({ type: ButtonType.Normal }) {
          Column({ space: 7 }) {
            Text('心理支持 · 12356').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#356D64')
            Text('有些时刻，需要一个真实的人陪你。').fontSize(13).fontColor('#507D76')
            Text('查看心理热线与紧急求助方式').fontSize(12).fontColor('#356D64')
          }.width('100%').alignItems(HorizontalAlign.Start)
        }.width('100%').padding(20).backgroundColor('#E8F5F0').borderRadius(22)
          .onClick(() => { this.open('pages/SupportPage'); })
      }.width('100%').constraintSize({ maxWidth: 680 }).padding({ left: 18, right: 18, top: 14, bottom: 20 })
    }.width('100%').height('100%').scrollBar(BarState.Off).backgroundColor(UiTokens.PAGE_BG_TOP)
      .bindSheet($$this.editingTools, this.ToolEditor(), { height: SheetSize.LARGE, showClose: true })
  }
  @Builder Stat(value: number, label: string) {
    Column({ space: 4 }) { Text(value.toString()).fontSize(20).fontWeight(FontWeight.Bold).fontColor(UiTokens.PRIMARY)
      Text(label).fontSize(10).fontColor(UiTokens.TEXT_SECONDARY)
    }.layoutWeight(1)
  }
  @Builder LinkRow(title: string, note: string, route: string) {
    Button({ type: ButtonType.Normal }) {
      Row() {
        Column({ space: 5 }) { Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(UiTokens.TEXT_PRIMARY)
          Text(note).fontSize(11).fontColor(UiTokens.TEXT_SECONDARY).maxLines(1)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text('›').fontSize(23).fontColor(UiTokens.TEXT_MUTED)
      }.width('100%')
    }.width('100%').height(68).padding(0).backgroundColor(Color.Transparent)
      .onClick(() => { this.open(route); })
  }
  @Builder GrowthCard() {
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
  @Builder Badge(item: BadgeItem) {
    Column({ space: 5 }) {
      Image($rawfile(item.asset.replace('.svg', '_color.svg'))).width(48).height(48).objectFit(ImageFit.Contain)
        .saturate(item.value >= item.target ? 1 : 0).opacity(item.value >= item.target ? 1 : 0.35)
      Text(item.name).fontSize(12).fontWeight(FontWeight.Medium).fontColor(item.value >= item.target ? this.badgeColor(item) : '#778493')
      Text(item.value >= item.target ? '已点亮' : Math.min(item.value, item.target).toString() + ' / ' + item.target.toString())
        .fontSize(10).fontColor(UiTokens.TEXT_SECONDARY)
    }.layoutWeight(1).height(102).justifyContent(FlexAlign.Center)
      .backgroundColor(item.value >= item.target ? this.badgeBackground(item) : '#F3F5F7').borderRadius(16)
      .onClick(() => { this.getUIContext().getPromptAction().showDialog({ title: item.name,
        message: (this.demo ? '当前为示例勋章，切换真实后显示你的实际进度。\n' : '') + '解锁条件：' + item.target.toString() + ' ' + item.unit + '。当前完成 ' + item.value.toString() + '。',
        buttons: [{ text: '知道了', color: UiTokens.PRIMARY }] }); })
  }
  @Builder ToolEditor() {
    Column({ space: 10 }) {
      if (this.sheetMode === 'badges') {
        Text('我的成就勋章').fontSize(21).fontWeight(FontWeight.Bold).width('100%')
        Text('点按勋章，查看解锁条件').fontSize(12).fontColor(UiTokens.TEXT_SECONDARY).width('100%')
        ForEach([0, 1, 2], (row: number) => {
          Row({ space: 8 }) {
            ForEach(this.badges().slice(row * 3, row * 3 + 3), (item: BadgeItem) => { this.Badge(item) })
          }.width('100%')
        })
      } else {
      Text('编辑常用工具').fontSize(21).fontWeight(FontWeight.Bold).width('100%')
      Text('选择 1–4 项，保存后显示在我的工具中').fontSize(12).fontColor(UiTokens.TEXT_SECONDARY).width('100%')
      ForEach(this.tools, (item: MyTool) => {
        Row({ space: 12 }) {
          Image($rawfile(item.asset)).width(32).height(32).objectFit(ImageFit.Contain)
          Text(item.name).fontSize(15).layoutWeight(1)
          Checkbox({ name: item.key }).select(this.draftTools.indexOf(item.key) >= 0)
            .onChange((selected: boolean) => { if (selected !== (this.draftTools.indexOf(item.key) >= 0)) { this.toggleTool(item.key); } })
        }.width('100%').height(52).padding({ left: 12, right: 12 }).backgroundColor(Color.White).borderRadius(14)
      }, (item: MyTool) => item.key)
      Button(this.savingTools ? '正在保存…' : '保存常用工具').width('100%').height(48).enabled(!this.savingTools)
        .backgroundColor(UiTokens.PRIMARY).onClick(() => { this.saveTools(); })
      }
    }.width('100%').padding({ left: 20, right: 20, top: 40, bottom: 20 })
  }
}
