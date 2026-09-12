import { MentalHealthRecord } from '../common/DataModels';
import { UiTokens } from '../common/UiTokens';
import { DatabaseService } from '../services/DatabaseService';
import { HapticService } from '../services/HapticService';
import { MentalHealthAnalyzer, MentalHealthInsight } from '../services/MentalHealthAnalyzer';

interface MoodPoint {
  label: string;
  value: number;
}

@Component
struct MoodTrendChart {
  @Prop @Watch('redraw') points: MoodPoint[] = [];
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private chartWidth: number = 320;
  private ready: boolean = false;

  private redraw(): void {
    if (!this.ready) {
      return;
    }
    const ctx: CanvasRenderingContext2D = this.context;
    const width: number = this.chartWidth;
    ctx.clearRect(0, 0, width, 142);
    const ticks: number[] = [0, 5, 10];
    for (let index: number = 0; index < ticks.length; index++) {
      const y: number = 112 - ticks[index] * 8.8;
      ctx.beginPath();
      ctx.moveTo(28, y);
      ctx.lineTo(width - 12, y);
      ctx.strokeStyle = '#DFE9EE';
      ctx.lineWidth = 1;
      ctx.stroke();
      ctx.fillStyle = '#82929F';
      ctx.font = '10px sans-serif';
      ctx.textAlign = 'start';
      ctx.fillText(ticks[index].toString(), 4, y + 3);
    }
    if (this.points.length === 0) {
      return;
    }
    const step: number = (width - 54) / Math.max(1, this.points.length - 1);
    ctx.beginPath();
    for (let index: number = 0; index < this.points.length; index++) {
      const x: number = 34 + index * step;
      const y: number = 112 - Math.max(0, Math.min(10, this.points[index].value)) * 8.8;
      if (index === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.strokeStyle = '#3E9EAD';
    ctx.lineWidth = 3;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.stroke();
    for (let index: number = 0; index < this.points.length; index++) {
      const x: number = 34 + index * step;
      const y: number = 112 - Math.max(0, Math.min(10, this.points[index].value)) * 8.8;
      ctx.beginPath();
      ctx.arc(x, y, 5, 0, Math.PI * 2);
      ctx.fillStyle = '#FFFFFF';
      ctx.fill();
      ctx.strokeStyle = '#3E9EAD';
      ctx.lineWidth = 2.5;
      ctx.stroke();
    }
  }

  build() {
    Column({ space: 2 }) {
      Canvas(this.context)
        .width('100%')
        .height(124)
        .onReady(() => { this.ready = true; this.redraw(); })
        .onAreaChange((_old: Area, area: Area) => {
          this.chartWidth = Number(area.width);
          this.redraw();
        })
      Row() {
        ForEach(this.points, (point: MoodPoint) => {
          Text(point.label).fontSize(9).fontColor(UiTokens.TEXT_MUTED)
            .layoutWeight(1).textAlign(TextAlign.Center).maxLines(1)
        })
      }.width('100%').padding({ left: 22, right: 2 })
    }
    .width('100%')
    .accessibilityText(this.points.map((point: MoodPoint) =>
      point.label + '，心情 ' + point.value.toString() + ' 分').join('；'))
  }
}

@Entry
@Component
struct MentalHealthPage {
  @StorageLink('dataRefreshVersion') refreshVersion: number = 0;
  @State records: MentalHealthRecord[] = [];
  @State rangeDays: number = 7;
  @State recording: boolean = false;
  @State saving: boolean = false;
  @State moodScore: number = 5;
  @State selectedEmotions: string[] = [];
  @State selectedFactors: string[] = [];
  @State note: string = '';
  @State recordStep: number = 0;
  @State failed: boolean = false;
  private readonly emotionOptions: string[] = ['平静', '开心', '安心', '期待', '焦虑', '低落', '烦躁', '疲惫'];
  private readonly factorOptions: string[] = ['学习', '考试', '睡眠', '家人', '朋友', '身体', '天气', '独处'];

  aboutToAppear(): void {
    this.loadRecords();
  }

  private async loadRecords(): Promise<void> {
    try {
      this.records = await DatabaseService.getMentalHealthRecords();
      this.failed = false;
    } catch (reason) {
      this.failed = true;
    }
  }

  private visibleRecords(): MentalHealthRecord[] {
    const threshold: number = Date.now() - this.rangeDays * 86400000;
    return this.records.filter((item: MentalHealthRecord) =>
      new Date(item.recordedAt).getTime() >= threshold);
  }

  private chartPoints(): MoodPoint[] {
    const visible: MentalHealthRecord[] = this.visibleRecords().slice(0, this.rangeDays === 7 ? 7 : 10).reverse();
    return visible.map((item: MentalHealthRecord) => {
      return { label: this.shortDate(item.recordedAt), value: item.moodScore } as MoodPoint;
    });
  }

  private insight(): MentalHealthInsight {
    return MentalHealthAnalyzer.analyze(this.visibleRecords());
  }

  private moodLabel(score: number): string {
    if (score <= 1) { return '非常不愉快'; }
    if (score <= 3) { return '有些低落'; }
    if (score <= 4) { return '不太轻松'; }
    if (score <= 6) { return '平静一般'; }
    if (score <= 8) { return '比较愉快'; }
    return '非常愉快';
  }

  private moodColor(score: number): string {
    if (score <= 3) { return '#7D89A9'; }
    if (score <= 6) { return '#4D9EB4'; }
    return '#3EAA82';
  }

  private toggleEmotion(value: string): void {
    HapticService.light();
    if (this.selectedEmotions.indexOf(value) >= 0) {
      this.selectedEmotions = this.selectedEmotions.filter((item: string) => item !== value);
      return;
    }
    if (this.selectedEmotions.length >= 3) {
      this.toast('最多选择 3 个最贴近的感受。');
      return;
    }
    this.selectedEmotions = this.selectedEmotions.concat([value]);
  }

  private toggleFactor(value: string): void {
    HapticService.light();
    if (this.selectedFactors.indexOf(value) >= 0) {
      this.selectedFactors = this.selectedFactors.filter((item: string) => item !== value);
    } else {
      this.selectedFactors = this.selectedFactors.concat([value]);
    }
  }

  private beginRecord(): void {
    this.moodScore = 5;
    this.selectedEmotions = [];
    this.selectedFactors = [];
    this.note = '';
    this.recordStep = 0;
    HapticService.light();
    this.recording = true;
  }

  private moveRecordStep(next: number): void {
    if (next < 0 || next > 2 || next === this.recordStep) {
      return;
    }
    HapticService.light();
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.recordStep = next;
    });
  }

  private selectRange(days: number): void {
    if (days === this.rangeDays) {
      return;
    }
    HapticService.light();
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.rangeDays = days;
    });
  }

  private async saveRecord(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    try {
      const item: MentalHealthRecord = {
        recordedAt: new Date().toISOString(),
        moodScore: this.moodScore,
        moodLabel: this.moodLabel(this.moodScore),
        emotions: this.selectedEmotions.slice(),
        factors: this.selectedFactors.slice(),
        note: this.note.trim(),
        source: 'daily'
      };
      item.id = await DatabaseService.addMentalHealthRecord(item);
      this.records = [item].concat(this.records);
      this.recording = false;
      HapticService.light();
      this.toast('这一刻已经替你收好。');
    } catch (reason) {
      this.toast('记录没有保存成功，请再试一次。');
    } finally {
      this.saving = false;
    }
  }

  private confirmDelete(item: MentalHealthRecord): void {
    if (item.id === undefined) {
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: '删除这条心情记录？',
      message: '删除后无法恢复。',
      buttons: [
        { text: '保留', color: UiTokens.TEXT_SECONDARY },
        { text: '删除', color: UiTokens.DANGER }
      ]
    }).then((result) => {
      if (result.index === 1 && item.id !== undefined) {
        this.deleteRecord(item.id);
      }
    });
  }

  private async deleteRecord(id: number): Promise<void> {
    try {
      await DatabaseService.deleteMentalHealthRecord(id);
      this.records = this.records.filter((item: MentalHealthRecord) => item.id !== id);
      this.toast('记录已删除。');
    } catch (reason) {
      this.toast('刚才没有删除成功。');
    }
  }

  private openAssessment(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/AssessmentRoutePage' }).catch(() => { this.toast('测评页暂时没有打开。'); });
  }

  private openSupport(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/SupportPage' }).catch(() => { this.toast('支持页面暂时没有打开。'); });
  }

  private shortDate(value: string): string {
    const date: Date = new Date(value);
    return (date.getMonth() + 1).toString() + '/' + date.getDate().toString();
  }

  private fullTime(value: string): string {
    const date: Date = new Date(value);
    const minute: string = date.getMinutes().toString().padStart(2, '0');
    return (date.getMonth() + 1).toString() + '月' + date.getDate().toString() + '日  ' +
      date.getHours().toString().padStart(2, '0') + ':' + minute;
  }

  private todayRecorded(): boolean {
    const now: Date = new Date();
    const today: string = now.getFullYear().toString() + '-' +
      (now.getMonth() + 1).toString().padStart(2, '0') + '-' + now.getDate().toString().padStart(2, '0');
    return this.records.some((item: MentalHealthRecord) => item.recordedAt.substring(0, 10) === today);
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2200 });
  }

  build() {
    Column() {
      this.TopBar()
      Scroll() {
        Column({ space: 14 }) {
          this.TodayCard()
          this.TrendCard()
          this.AnalysisCard()
          this.RecordList()
          Text('记录与分析仅用于自我观察，不替代医生或心理专业人员的判断。')
            .fontSize(10).lineHeight(16).fontColor(UiTokens.TEXT_MUTED).textAlign(TextAlign.Center)
            .padding({ left: 18, right: 18, bottom: 12 })
        }
        .width('100%').constraintSize({ maxWidth: 680 })
        .padding({ left: 16, right: 16, bottom: 22 })
      }
      .layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }
    .width('100%').height('100%')
    .linearGradient({ angle: 150, colors: [[UiTokens.PAGE_BG_TOP, 0], ['#EEF7F5', 1]] })
    .bindSheet($$this.recording, this.RecordSheet(), { height: SheetSize.LARGE, showClose: true })
  }

  @Builder
  TopBar() {
    Row({ space: 12 }) {
      Button({ type: ButtonType.Circle }) {
        Image($rawfile('back_arrow.svg')).width(22).height(22)
      }.width(44).height(44).backgroundColor(Color.White)
        .border({ width: 1, color: UiTokens.CARD_BORDER }).accessibilityText('返回')
        .onClick(() => { this.getUIContext().getRouter().back(); })
      Column({ space: 2 }) {
        Text('心理状态').fontSize(21).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
        Text('日常记录 · 趋势观察').fontSize(11).fontColor(UiTokens.TEXT_SECONDARY)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button('专业量表').height(44).fontSize(12).fontColor(UiTokens.PRIMARY)
        .backgroundColor(UiTokens.SURFACE_BLUE).borderRadius(18)
        .onClick(() => { this.openAssessment(); })
    }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 10 })
  }

  @Builder
  TodayCard() {
    Row({ space: 12 }) {
      Column({ space: 7 }) {
        Text(this.todayRecorded() ? '今天已经留下记录' : '今天感觉怎么样？')
          .fontSize(19).fontWeight(FontWeight.Bold).fontColor('#244853')
        Text(this.records.length > 0 ? '最近一次：' + this.records[0].moodLabel : '花一分钟，看见此刻真实的自己')
          .fontSize(12).fontColor('#607B82').maxLines(2)
        Button(this.todayRecorded() ? '再记录一次' : '记录此刻')
          .height(44).fontSize(13).fontWeight(FontWeight.Medium).fontColor(Color.White)
          .backgroundColor('#3E9EAD').borderRadius(20).onClick(() => { this.beginRecord(); })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Stack({ alignContent: Alignment.Center }) {
        Circle().width(92).height(92).fill(this.records.length > 0 ? '#E0F3F1' : '#EAF2F4')
        Circle().width(66).height(66).fill(this.records.length > 0 ? this.moodColor(this.records[0].moodScore) : '#B8C9CE')
          .opacity(0.22)
        Text(this.records.length > 0 ? this.records[0].moodScore.toString() : '—')
          .fontSize(27).fontWeight(FontWeight.Bold)
          .fontColor(this.records.length > 0 ? this.moodColor(this.records[0].moodScore) : '#799098')
      }.width(100).height(100).accessibilityText(this.records.length > 0 ?
        '最近心情 ' + this.records[0].moodScore.toString() + ' 分' : '还没有心情记录')
    }
    .width('100%').padding(18).linearGradient({ angle: 125, colors: [['#FFFFFF', 0], ['#E8F6F4', 1]] })
    .border({ width: 1, color: '#D8EAE8' }).borderRadius(26)
  }

  @Builder
  TrendCard() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text('心情趋势').fontSize(17).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
          Text('分数越高，表示当下感受越舒展').fontSize(10).fontColor(UiTokens.TEXT_MUTED)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Row({ space: 2 }) {
          this.RangeButton('7 日', 7)
          this.RangeButton('30 日', 30)
        }.padding(3).backgroundColor('#EEF2F4').borderRadius(16)
      }.width('100%')
      if (this.chartPoints().length > 0) {
        MoodTrendChart({ points: this.chartPoints() })
        Row() {
          this.SummaryStat(this.insight().average.toFixed(1), '平均心情')
          this.SummaryStat(this.insight().trackedDays.toString(), '记录天数')
          this.SummaryStat(this.insight().topFactor, '主要关联')
        }.width('100%')
      } else {
        Column({ space: 9 }) {
          Text('还没有可展示的数据').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#506B75')
          Text('完成第一次日常记录后，趋势会从这里开始。').fontSize(11).fontColor(UiTokens.TEXT_MUTED)
          Button('开始第一次记录').height(44).fontSize(12).fontColor('#2F7F8A')
            .backgroundColor('#E6F4F3').borderRadius(18).onClick(() => { this.beginRecord(); })
        }.width('100%').height(150).justifyContent(FlexAlign.Center)
      }
    }.width('100%').padding(16).backgroundColor(Color.White)
      .border({ width: 1, color: UiTokens.CARD_BORDER }).borderRadius(24)
  }

  @Builder
  RangeButton(label: string, days: number) {
    Button(label).height(34).fontSize(11)
      .fontColor(this.rangeDays === days ? '#276F79' : UiTokens.TEXT_SECONDARY)
      .backgroundColor(this.rangeDays === days ? Color.White : Color.Transparent)
      .borderRadius(13).onClick(() => { this.selectRange(days); })
  }

  @Builder
  SummaryStat(value: string, label: string) {
    Column({ space: 3 }) {
      Text(value).fontSize(value.length > 6 ? 12 : 16).fontWeight(FontWeight.Bold).fontColor('#316F78').maxLines(1)
      Text(label).fontSize(9).fontColor(UiTokens.TEXT_MUTED)
    }.layoutWeight(1).height(48).justifyContent(FlexAlign.Center)
      .backgroundColor('#F1F8F7').borderRadius(14)
  }

  @Builder
  AnalysisCard() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('本地轻分析').fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor(this.insight().attention ? '#A85252' : '#397781')
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(this.insight().attention ? '#FFF0EF' : '#E8F5F3').borderRadius(12)
        Blank()
        Text('不上传记录').fontSize(10).fontColor(UiTokens.TEXT_MUTED)
      }.width('100%')
      Text(this.insight().title).fontSize(18).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
        .width('100%')
      Text(this.insight().summary).fontSize(12).lineHeight(19).fontColor(UiTokens.TEXT_SECONDARY).width('100%')
      Row({ space: 8 }) {
        Text('观察').fontSize(10).fontColor('#397781')
        Text(this.insight().pattern).fontSize(11).fontColor('#536D75').layoutWeight(1).maxLines(2)
      }.width('100%').padding(10).backgroundColor('#F4F8F8').borderRadius(14)
      Row({ space: 8 }) {
        Text('下一步').fontSize(10).fontColor('#397781')
        Text(this.insight().suggestion).fontSize(11).lineHeight(17).fontColor('#536D75').layoutWeight(1)
      }.width('100%').padding(10).backgroundColor('#F4F8F8').borderRadius(14)
      if (this.insight().attention) {
        Button('查看心理支持').width('100%').height(44).fontSize(12).fontColor('#97504C')
          .backgroundColor('#FFF0EF').borderRadius(18).onClick(() => { this.openSupport(); })
      }
    }.width('100%').padding(16).backgroundColor(Color.White)
      .border({ width: 1, color: this.insight().attention ? '#F0D1CE' : UiTokens.CARD_BORDER }).borderRadius(24)
  }

  @Builder
  RecordList() {
    Column({ space: 10 }) {
      Row() {
        Text('最近记录').fontSize(17).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY).layoutWeight(1)
        Text(this.records.length.toString() + ' 条').fontSize(10).fontColor(UiTokens.TEXT_MUTED)
      }.width('100%')
      if (this.failed) {
        Text('记录暂时没有加载出来，返回后可以再试。').fontSize(12).fontColor(UiTokens.DANGER)
          .width('100%').padding(16).backgroundColor('#FFF3F2').borderRadius(18)
      } else if (this.records.length === 0) {
        Text('日常记录会按时间保存在这里。').fontSize(12).fontColor(UiTokens.TEXT_MUTED)
          .width('100%').padding(16).backgroundColor(Color.White).borderRadius(18)
      } else {
        ForEach(this.records.slice(0, 8), (item: MentalHealthRecord) => { this.RecordRow(item) },
          (item: MentalHealthRecord) => item.id === undefined ? item.recordedAt : item.id.toString())
      }
    }.width('100%')
  }

  @Builder
  RecordRow(item: MentalHealthRecord) {
    Row({ space: 11 }) {
      Column({ space: 1 }) {
        Text(item.moodScore.toString()).fontSize(19).fontWeight(FontWeight.Bold).fontColor(this.moodColor(item.moodScore))
        Text('/ 10').fontSize(9).fontColor(UiTokens.TEXT_MUTED)
      }.width(48).height(48).justifyContent(FlexAlign.Center).backgroundColor('#EEF7F6').borderRadius(16)
      Column({ space: 4 }) {
        Row({ space: 7 }) {
          Text(item.moodLabel).fontSize(14).fontWeight(FontWeight.Medium).fontColor(UiTokens.TEXT_PRIMARY)
          Text(item.source === 'breathing' ? '呼吸后' : '日常').fontSize(9).fontColor('#3C7D85')
            .padding({ left: 7, right: 7, top: 3, bottom: 3 }).backgroundColor('#E9F5F3').borderRadius(8)
        }
        Text(this.fullTime(item.recordedAt) + (item.emotions.length > 0 ? ' · ' + item.emotions.join('、') : ''))
          .fontSize(10).fontColor(UiTokens.TEXT_SECONDARY).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (item.note.length > 0) {
          Text(item.note).fontSize(10).fontColor(UiTokens.TEXT_MUTED).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button('删除').width(52).height(44).fontSize(10).fontColor(UiTokens.TEXT_MUTED)
        .backgroundColor(Color.Transparent).onClick(() => { this.confirmDelete(item); })
    }.width('100%').padding({ left: 12, right: 4, top: 11, bottom: 11 })
      .backgroundColor(Color.White).border({ width: 1, color: UiTokens.CARD_BORDER }).borderRadius(18)
  }

  @Builder
  RecordSheet() {
    Column({ space: 14 }) {
      Column({ space: 10 }) {
        Row() {
          Column({ space: 4 }) {
            Text('记录此刻').fontSize(23).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
            Text(['选择感受', '补充线索', '留下一句话'][this.recordStep])
              .fontSize(12).fontColor(UiTokens.TEXT_SECONDARY)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text((this.recordStep + 1).toString() + ' / 3').fontSize(11).fontColor('#397781')
        }.width('100%')
        Row({ space: 6 }) {
          ForEach([0, 1, 2], (step: number) => {
            Column().layoutWeight(1).height(5).borderRadius(3)
              .backgroundColor(step <= this.recordStep ? '#3E9EAD' : '#DCE8EA')
          })
        }.width('100%')
      }.width('100%')
      Scroll() {
        Column() {
          if (this.recordStep === 0) {
            this.MoodStep()
          } else if (this.recordStep === 1) {
            this.DetailStep()
          } else {
            this.NoteStep()
          }
        }.width('100%').padding({ top: 4, bottom: 8 })
          .opacity(1).animation({ duration: 200, curve: Curve.EaseOut })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
      Row({ space: 10 }) {
        if (this.recordStep > 0) {
          Button('上一步').layoutWeight(1).height(50).fontSize(14).fontColor('#397781')
            .backgroundColor('#E9F4F3').borderRadius(22)
            .onClick(() => { this.moveRecordStep(this.recordStep - 1); })
        }
        if (this.recordStep < 2) {
          Button('下一步').layoutWeight(2).height(50).fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor(Color.White).backgroundColor('#3E9EAD').borderRadius(22)
            .onClick(() => { this.moveRecordStep(this.recordStep + 1); })
        } else {
          Button(this.saving ? '正在保存…' : '保存这次记录').layoutWeight(2).height(50).enabled(!this.saving)
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
            .backgroundColor('#3E9EAD').borderRadius(22).onClick(() => { this.saveRecord(); })
        }
      }.width('100%')
      Text('记录保存在本机，可随时删除。').width('100%').textAlign(TextAlign.Center)
        .fontSize(10).fontColor(UiTokens.TEXT_MUTED)
    }.width('100%').height('100%').padding({ left: 20, right: 20, top: 26, bottom: 18 })
  }

  @Builder
  MoodStep() {
    Column({ space: 14 }) {
      Text('此刻整体感觉如何？').fontSize(17).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
        .width('100%')
      Stack({ alignContent: Alignment.Center }) {
        Circle().width(190).height(190).fill('#F0F8F7')
        Circle().width(146).height(146).fill('#DDF1EF')
        Circle().width(98).height(98).fill(this.moodColor(this.moodScore)).opacity(0.24)
        Column({ space: 3 }) {
          Text(this.moodScore.toString()).fontSize(36).fontWeight(FontWeight.Bold).fontColor(this.moodColor(this.moodScore))
          Text(this.moodLabel(this.moodScore)).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#506F76')
        }
      }.width('100%').height(210)
      Slider({ value: this.moodScore, min: 0, max: 10, step: 1 })
        .selectedColor(this.moodColor(this.moodScore)).trackColor('#DCE8EA').blockColor(Color.White)
        .onChange((value: number) => { this.moodScore = Math.round(value); })
      Row() {
        Text('非常不愉快').fontSize(10).fontColor(UiTokens.TEXT_MUTED).layoutWeight(1)
        Text('平静').fontSize(10).fontColor(UiTokens.TEXT_MUTED).layoutWeight(1).textAlign(TextAlign.Center)
        Text('非常愉快').fontSize(10).fontColor(UiTokens.TEXT_MUTED).layoutWeight(1).textAlign(TextAlign.End)
      }.width('100%')
      Text('没有标准答案，停在最贴近此刻的位置就好。').fontSize(11).fontColor(UiTokens.TEXT_MUTED)
        .width('100%').textAlign(TextAlign.Center)
    }.width('100%').padding(16).backgroundColor('#F8FBFA').borderRadius(24)
  }

  @Builder
  DetailStep() {
    Column({ space: 22 }) {
      this.OptionSection('哪些感受最贴近？', '最多选 3 个', this.emotionOptions, true)
      Divider().color('#E5EDEF')
      this.OptionSection('什么影响了现在的你？', '可多选', this.factorOptions, false)
      Text('不知道也没关系，这一步可以直接跳过。').fontSize(11).fontColor(UiTokens.TEXT_MUTED)
        .width('100%').textAlign(TextAlign.Center)
    }.width('100%').padding(16).backgroundColor('#FAFCFC').borderRadius(24)
  }

  @Builder
  NoteStep() {
    Column({ space: 16 }) {
      Column({ space: 6 }) {
        Text('为这一刻留句话').fontSize(17).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
        Text('以后回看趋势时，这句话会帮助你想起当时发生了什么。').fontSize(11)
          .lineHeight(17).fontColor(UiTokens.TEXT_SECONDARY)
      }.width('100%').alignItems(HorizontalAlign.Start)
      TextArea({ text: this.note, placeholder: '选填，例如：今天完成了最难的一项任务。' })
        .width('100%').height(132).fontSize(13).backgroundColor('#F2F6F7').borderRadius(18)
        .onChange((value: string) => { this.note = value.substring(0, 120); })
      Text(this.note.length.toString() + ' / 120').width('100%').textAlign(TextAlign.End)
        .fontSize(9).fontColor(UiTokens.TEXT_MUTED)
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text(this.moodScore.toString() + ' / 10').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.moodColor(this.moodScore))
          Text(this.moodLabel(this.moodScore)).fontSize(10).fontColor(UiTokens.TEXT_MUTED)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column({ space: 3 }) {
          Text(this.selectedEmotions.length > 0 ? this.selectedEmotions.join('、') : '未选择感受')
            .fontSize(11).fontColor('#526C74').maxLines(2)
          Text(this.selectedFactors.length > 0 ? '关联：' + this.selectedFactors.join('、') : '未选择影响因素')
            .fontSize(10).fontColor(UiTokens.TEXT_MUTED).maxLines(2)
        }.layoutWeight(2).alignItems(HorizontalAlign.Start)
      }.width('100%').padding(14).backgroundColor('#EAF6F4').borderRadius(18)
    }.width('100%').padding(16).backgroundColor('#FAFCFC').borderRadius(24)
  }

  @Builder
  OptionSection(title: string, hint: string, options: string[], emotion: boolean) {
    Column({ space: 9 }) {
      Row() {
        Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(UiTokens.TEXT_PRIMARY).layoutWeight(1)
        Text(hint).fontSize(10).fontColor(UiTokens.TEXT_MUTED)
      }.width('100%')
      ForEach([0, 1], (row: number) => {
        Row({ space: 8 }) {
          ForEach(options.slice(row * 4, row * 4 + 4), (value: string) => {
            this.OptionChip(value, emotion)
          })
        }.width('100%')
      })
    }.width('100%')
  }

  @Builder
  OptionChip(value: string, emotion: boolean) {
    Button(value).layoutWeight(1).height(42).fontSize(11)
      .fontColor((emotion ? this.selectedEmotions : this.selectedFactors).indexOf(value) >= 0 ? Color.White : '#526C74')
      .backgroundColor((emotion ? this.selectedEmotions : this.selectedFactors).indexOf(value) >= 0 ? '#3E9EAD' : '#EEF4F4')
      .borderRadius(17)
      .scale({ x: (emotion ? this.selectedEmotions : this.selectedFactors).indexOf(value) >= 0 ? 1.03 : 1,
        y: (emotion ? this.selectedEmotions : this.selectedFactors).indexOf(value) >= 0 ? 1.03 : 1 })
      .animation({ duration: 160, curve: Curve.EaseOut })
      .onClick(() => { if (emotion) { this.toggleEmotion(value); } else { this.toggleFactor(value); } })
  }
}
