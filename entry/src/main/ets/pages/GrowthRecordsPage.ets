import { DemoGrowthService, DemoGrowthRecord } from '../services/DemoGrowthService';
import { SettingsService } from '../services/SettingsService';
import { UiTokens } from '../common/UiTokens';
import { PageHeader } from '../components/PageHeader';
import { DatabaseService } from '../services/DatabaseService';
import { CardDrawRecord, ThoughtChallenge, AssessmentRecord, TrainingRecord } from '../common/DataModels';

interface RecordRoute { filter?: number; }
interface HistoryItem { key: string; kind: number; title: string; text: string; date: string; }
@Entry
@Component
struct GrowthRecordsPage {
  @StorageLink('growthDemo') @Watch('resetPage') demo: boolean = true;
  @State changingDemo: boolean = false;
  @State rows: HistoryItem[] = [];
  @State filter: number = 0;
  @State page: number = 0;
  @State loading: boolean = true;
  @State error: boolean = false;
  private historyScroller: Scroller = new Scroller();
  private readonly labels: string[] = ['全部', '翻卡', '调节', '重构', '测评'];
  aboutToAppear(): void {
    const params: RecordRoute = this.getUIContext().getRouter().getParams() as RecordRoute;
    const filter: number = params?.filter ?? 0;
    this.filter = Math.max(0, Math.min(4, filter)); this.load();
  }
  private resetPage(): void { this.page = 0; this.historyScroller.scrollEdge(Edge.Top); }
  private async load(): Promise<void> {
    this.loading = true; this.error = false;
    try {
      this.demo = await SettingsService.growthDemoEnabled();
      const cards: CardDrawRecord[] = await DatabaseService.getCardDraws();
      const trainings: TrainingRecord[] = await DatabaseService.getAllTrainingRecords();
      const challenges: ThoughtChallenge[] = await DatabaseService.getAllThoughtChallenges();
      const assessments: AssessmentRecord[] = await DatabaseService.getAllAssessments();
      const items: HistoryItem[] = [];
      cards.forEach((item: CardDrawRecord) => { items.push({ key: 'card_' + item.id, kind: 1,
        title: '翻卡 · ' + item.category, text: item.content, date: item.drawnAt }); });
      trainings.forEach((item: TrainingRecord) => { items.push({ key: 'training_' + item.id, kind: 2,
        title: item.type === 'breathing' || item.type === 'breath' ? '云息呼吸' : (item.type === 'rest' ? '松风休息' : item.type),
        text: '完成 ' + Math.floor(item.duration / 60).toString() + ' 分 ' + (item.duration % 60).toString() + ' 秒练习', date: item.date }); });
      challenges.forEach((item: ThoughtChallenge) => { items.push({ key: 'thought_' + item.id, kind: 3,
        title: '认知重构 · ' + item.distortionType,
        text: '原来的想法：' + item.negativeThought + '\n新的看法：' + item.alternativeThought, date: item.createdAt }); });
      assessments.forEach((item: AssessmentRecord) => { items.push({ key: 'assessment_' + item.id, kind: 4,
        title: item.type + ' 测评', text: '压力参考值 ' + item.stressLevel.toFixed(1) + ' / 10 · 仅供自我了解', date: item.date }); });
      items.sort((a: HistoryItem, b: HistoryItem) => b.date.localeCompare(a.date));
      this.rows = items;
    } catch (reason) { this.error = true; }
    finally { this.loading = false; }
  }
  private selectedRows(): HistoryItem[] { return (this.demo ? DemoGrowthService.records().map((item: DemoGrowthRecord): HistoryItem => { return { key: item.key, kind: item.kind, title: item.title, text: item.text, date: item.date }; }) : this.rows).filter((item: HistoryItem) => this.filter === 0 || item.kind === this.filter); }
  private pages(): number { return Math.max(1, Math.ceil(this.selectedRows().length / 12)); }
  private dateLabel(date: string): string {
    const value: Date = new Date(date);
    return Number.isFinite(value.getTime()) ? value.toLocaleString('zh-CN') : date;
  }
  build() {
    Column() {
      PageHeader({ title: '我的成长记录' })
      Row({ space: 8 }) {
        Text(this.demo ? '示例记录 · 不计入真实成长' : '真实记录 · 来自你的使用').fontSize(12).fontColor('#86682E').layoutWeight(1)
        Button(this.demo ? '切换真实' : '看看示例').fontSize(12).height(44).enabled(!this.changingDemo)
          .onClick(async () => { this.changingDemo = true; try { await SettingsService.saveGrowthDemo(!this.demo); }
            catch (reason) { this.getUIContext().getPromptAction().showToast({ message: '切换失败，请重试。' }); }
            finally { this.changingDemo = false; } })
      }.width('100%').padding({ left: 16, right: 16 }).backgroundColor('#FFF9EC')
      Row({ space: 6 }) {
        ForEach(this.labels, (label: string, index: number) => {
          Button(label).height(44).layoutWeight(1).fontSize(12)
            .backgroundColor(this.filter === index ? UiTokens.PRIMARY : Color.White)
            .fontColor(this.filter === index ? Color.White : UiTokens.TEXT_SECONDARY)
            .onClick(() => { this.filter = index; this.page = 0; this.historyScroller.scrollEdge(Edge.Top); })
        })
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 10 })
      Text('共 ' + this.selectedRows().length.toString() + ' 条 · 每一小步都有记录')
        .fontSize(12).fontColor(UiTokens.TEXT_SECONDARY).width('100%').padding({ left: 20, bottom: 10 })
      Scroll(this.historyScroller) {
        Column({ space: 10 }) {
          if (this.loading) { Text('正在整理记录…').padding(24) }
          else if (this.error) { Button('加载失败，点此重试').height(44).onClick(() => { this.load(); }) }
          else if (this.selectedRows().length === 0) {
            Image($rawfile('kxq_ip_reading.png')).width(100).height(100).objectFit(ImageFit.Contain).margin({ top: 40 })
            Text('这里还没有记录').fontSize(18).fontWeight(FontWeight.Bold)
            Text('完成翻卡、呼吸、休息或测评后，再来看看。').fontSize(13).fontColor(UiTokens.TEXT_SECONDARY)
          } else {
            ForEach(this.selectedRows().slice(this.page * 12, this.page * 12 + 12), (item: HistoryItem) => {
              Column({ space: 8 }) {
                Text(item.title).fontSize(15).fontWeight(FontWeight.Bold).fontColor(UiTokens.PRIMARY)
                Text(item.text).fontSize(14).lineHeight(22).fontColor(UiTokens.TEXT_PRIMARY).copyOption(CopyOptions.LocalDevice)
                Text(this.dateLabel(item.date)).fontSize(11).fontColor(UiTokens.TEXT_SECONDARY)
              }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(Color.White).borderRadius(20)
            }, (item: HistoryItem) => item.key)
          }
        }.width('100%').constraintSize({ maxWidth: 680 }).padding({ left: 16, right: 16, bottom: 16 })
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
      Row({ space: 12 }) {
        Button('上一页').height(44).layoutWeight(1).enabled(this.page > 0).onClick(() => { this.page--; this.historyScroller.scrollEdge(Edge.Top); })
        Text((this.page + 1).toString() + ' / ' + this.pages().toString()).fontSize(13)
        Button('下一页').height(44).layoutWeight(1).enabled(this.page + 1 < this.pages()).onClick(() => { this.page++; this.historyScroller.scrollEdge(Edge.Top); })
      }.width('100%').padding(16)
    }.width('100%').height('100%').backgroundColor(UiTokens.PAGE_BG_TOP)
  }
}
