import { router } from '@kit.ArkUI';
import { AppConstants, ExamScore } from '../common/DataModels';
import { DatabaseService } from '../services/DatabaseService';
import { UiTokens } from '../common/UiTokens';

@Component
struct ScoreChart {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @Prop @Watch('redraw') scores: ExamScore[] = [];

  redraw(): void {
    this.draw();
  }

  private draw(): void {
    const ctx: CanvasRenderingContext2D = this.context;
    const width: number = 320;
    const height: number = 190;
    ctx.clearRect(0, 0, width, height);
    ctx.strokeStyle = '#338899AA';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(28, 12);
    ctx.lineTo(28, 162);
    ctx.lineTo(312, 162);
    ctx.stroke();
    if (this.scores.length === 0) {
      ctx.fillStyle = AppConstants.COLOR_TEXT_TERTIARY;
      ctx.font = '13px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('录入成绩后，这里会生成对比图', 170, 92);
      return;
    }
    const gap: number = 280 / this.scores.length;
    const barWidth: number = Math.min(30, gap * 0.55);
    for (let index: number = 0; index < this.scores.length; index++) {
      const ratio: number = this.scores[index].fullScore <= 0 ?
        0 : this.scores[index].score / this.scores[index].fullScore;
      const barHeight: number = Math.max(2, Math.min(1, ratio) * 132);
      const x: number = 30 + gap * index + (gap - barWidth) / 2;
      ctx.fillStyle = AppConstants.COLOR_PRIMARY;
      ctx.fillRect(x, 161 - barHeight, barWidth, barHeight);
      ctx.fillStyle = AppConstants.COLOR_TEXT_SECONDARY;
      ctx.font = '10px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(this.scores[index].subject.substring(0, 4), x + barWidth / 2, 178);
    }
  }

  build() {
    Canvas(this.context)
      .width(320)
      .height(190)
      .onReady(() => {
        this.draw();
      })
  }
}

@Entry
@Component
struct AnalysisPage {
  @State scores: ExamScore[] = [];
  @State editingId: number = -1;
  @State subject: string = '';
  @State scoreText: string = '';
  @State fullScoreText: string = '';
  @State saving: boolean = false;

  aboutToAppear(): void {
    this.loadScores();
  }

  private async loadScores(): Promise<void> {
    try {
      this.scores = await DatabaseService.getAllExamScores();
    } catch (reason) {
      this.showToast('成绩记录暂时没有加载出来。');
    }
  }

  private averageRatio(): number {
    if (this.scores.length === 0) {
      return 0;
    }
    let sum: number = 0;
    for (let index: number = 0; index < this.scores.length; index++) {
      if (this.scores[index].fullScore > 0) {
        sum += this.scores[index].score / this.scores[index].fullScore * 100;
      }
    }
    return sum / this.scores.length;
  }

  private strongestScore(): ExamScore | undefined {
    if (this.scores.length === 0) { return undefined; }
    let result: ExamScore = this.scores[0];
    for (let index: number = 1; index < this.scores.length; index++) {
      if (this.ratio(this.scores[index]) > this.ratio(result)) { result = this.scores[index]; }
    }
    return result;
  }

  private focusScore(): ExamScore | undefined {
    if (this.scores.length === 0) { return undefined; }
    let result: ExamScore = this.scores[0];
    for (let index: number = 1; index < this.scores.length; index++) {
      if (this.ratio(this.scores[index]) < this.ratio(result)) { result = this.scores[index]; }
    }
    return result;
  }

  private ratio(item: ExamScore): number {
    return item.fullScore > 0 ? item.score / item.fullScore * 100 : 0;
  }

  private scoreLabel(item: ExamScore): string {
    const value: number = this.ratio(item);
    if (value >= 85) { return '掌握稳定'; }
    if (value >= 60) { return '继续巩固'; }
    return '优先复盘';
  }

  private scoreAdvice(item: ExamScore): string {
    const value: number = this.ratio(item);
    if (value >= 85) { return '保持当前节奏，抽时间整理易错点。'; }
    if (value >= 60) { return '回看错题，找出丢分最多的一类。'; }
    return '先拆出 1 个最常见的失分原因，再安排短时复习。';
  }

  private async saveScore(): Promise<void> {
    const scoreValue: number = Number(this.scoreText);
    const fullValue: number = Number(this.fullScoreText);
    if (this.subject.trim().length === 0 || isNaN(scoreValue) || isNaN(fullValue) ||
      fullValue <= 0 || scoreValue < 0 || scoreValue > fullValue) {
      this.showToast('请检查科目、分数和满分是否填写正确。');
      return;
    }
    this.saving = true;
    const item: ExamScore = {
      subject: this.subject.trim(),
      score: scoreValue,
      fullScore: fullValue
    };
    try {
      if (this.editingId > 0) {
        item.id = this.editingId;
        await DatabaseService.updateExamScore(item);
      } else {
        await DatabaseService.addExamScore(item);
      }
      await this.loadScores();
      this.clearEditor();
      this.showToast('成绩已保存，复习重点已更新。');
    } catch (reason) {
      this.showToast('成绩没有保存成功，再试一次？');
    } finally {
      this.saving = false;
    }
  }

  private editScore(item: ExamScore): void {
    this.editingId = item.id === undefined ? -1 : item.id;
    this.subject = item.subject;
    this.scoreText = item.score.toString();
    this.fullScoreText = item.fullScore.toString();
  }

  private clearEditor(): void {
    this.editingId = -1;
    this.subject = '';
    this.scoreText = '';
    this.fullScoreText = '';
  }

  private confirmDelete(item: ExamScore): void {
    if (item.id === undefined) {
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: '删除成绩',
      message: '确定删除“' + item.subject + '”这条成绩吗？',
      buttons: [
        { text: '取消', color: AppConstants.COLOR_TEXT_SECONDARY },
        { text: '删除', color: AppConstants.COLOR_DANGER }
      ]
    }).then((result) => {
      if (result.index === 1 && item.id !== undefined) {
        this.deleteScore(item.id);
      }
    });
  }

  private async deleteScore(id: number): Promise<void> {
    try {
      await DatabaseService.deleteExamScore(id);
      await this.loadScores();
      if (this.editingId === id) {
        this.clearEditor();
      }
      this.showToast('这条成绩已删除。');
    } catch (reason) {
      this.showToast('刚才没有删除成功，再试一次？');
    }
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2500 });
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Button({ type: ButtonType.Circle }) {
          Image($rawfile('back_arrow.svg')).width(24).height(24)
      }
        .width(44).height(44).accessibilityText('返回')
        .backgroundColor('#26FFFFFF')
        .onClick(() => {
          router.back();
        })
        Text('考后分析')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Scroll() {
        Column({ space: 12 }) {
          this.AnalysisHero()
          Column({ space: 12 }) {
            Row() {
              Column({ space: 3 }) {
                Text(this.editingId > 0 ? '编辑成绩' : '记录一门成绩')
                  .fontSize(16).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
                Text('把分数记下来，复盘才有依据')
                  .fontSize(11).fontColor(UiTokens.TEXT_SECONDARY)
              }
              .alignItems(HorizontalAlign.Start).layoutWeight(1)
              if (this.editingId > 0) {
                Text('编辑中').fontSize(11).fontColor(UiTokens.PRIMARY)
                  .padding({ left: 9, right: 9, top: 4, bottom: 4 })
                  .backgroundColor(UiTokens.SURFACE_BLUE).borderRadius(10)
              }
            }
            .width('100%')
            Row({ space: 8 }) {
              TextInput({ placeholder: '科目', text: this.subject })
                .layoutWeight(1)
                .height(44)
                .backgroundColor('#BFFFFFFF')
                .borderRadius(12)
                .onChange((value: string) => {
                  this.subject = value;
                })
              TextInput({ placeholder: '得分', text: this.scoreText })
                .width(84)
                .height(44)
                .type(InputType.Number)
                .backgroundColor('#BFFFFFFF')
                .borderRadius(12)
                .onChange((value: string) => {
                  this.scoreText = value;
                })
              TextInput({ placeholder: '总分', text: this.fullScoreText })
                .width(84)
                .height(44)
                .type(InputType.Number)
                .backgroundColor('#BFFFFFFF')
                .borderRadius(12)
                .onChange((value: string) => {
                  this.fullScoreText = value;
                })
            }
            Row({ space: 10 }) {
              if (this.editingId > 0) {
                Button('取消编辑')
                  .layoutWeight(1)
                  .height(44)
                  .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
                  .backgroundColor('#33FFFFFF')
                  .onClick(() => {
                    this.clearEditor();
                  })
              }
              Button(this.saving ? '保存中…' : this.editingId > 0 ? '更新成绩' : '添加成绩')
                .layoutWeight(1)
                .height(44)
                .enabled(!this.saving)
                .fontColor(AppConstants.COLOR_WHITE)
                .backgroundColor(AppConstants.COLOR_PRIMARY)
                .onClick(() => {
                  this.saveScore();
                })
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor(UiTokens.CARD_SOLID)
          .border({ width: 1, color: UiTokens.CARD_BORDER })
          .borderRadius(UiTokens.CARD_RADIUS)

          Column({ space: 4 }) {
            Row() {
              Column({ space: 2 }) {
                Text('成绩概览').fontSize(16).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
                Text(this.scores.length === 0 ? '先记下一门成绩，再看看复习重点' : '按得分率查看当前复习重点')
                  .fontSize(11).fontColor(UiTokens.TEXT_SECONDARY)
              }
              .alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text(this.scores.length.toString() + ' 门').fontSize(11).fontColor(UiTokens.TEXT_MUTED)
            }
            .width('100%')
            Text('平均得分率')
              .fontSize(13)
              .fontColor(UiTokens.TEXT_SECONDARY)
            Text(this.averageRatio().toFixed(1) + '%')
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor(UiTokens.PRIMARY)
            ScoreChart({ scores: this.scores })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(UiTokens.CARD_SOLID)
          .border({ width: 1, color: UiTokens.CARD_BORDER })
          .borderRadius(UiTokens.CARD_RADIUS)

          this.InsightOverview()

          if (this.focusScore() !== undefined) {
            this.InsightCard(this.focusSubject(), '下一步建议', this.focusAdvice())
          }

          Column({ space: 8 }) {
            Row() {
              Text('成绩记录')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
              Blank()
              Text(this.scores.length.toString() + ' 条')
                .fontSize(12)
                .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
            }
            .width('100%')

            if (this.scores.length === 0) {
              Text('还没有录入成绩，考完了记得来记录哦。')
                .width('100%')
                .padding({ top: 24, bottom: 24 })
                .textAlign(TextAlign.Center)
                .fontSize(14)
                .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
            } else {
              ForEach(this.scores, (item: ExamScore) => {
                Row({ space: 8 }) {
                  Column({ space: 3 }) {
                    Text(item.subject)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
                    Text(item.score.toString() + ' / ' + item.fullScore.toString())
                      .fontSize(12)
                      .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Column({ space: 2 }) {
                    Text(this.ratio(item).toFixed(0) + '%')
                      .fontSize(14).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
                    Text(this.scoreLabel(item)).fontSize(10).fontColor(UiTokens.TEXT_MUTED)
                  }
                  Button('编辑')
                    .height(38)
                    .fontSize(12)
                    .fontColor(AppConstants.COLOR_PRIMARY)
                    .backgroundColor('#14007DFF')
                    .accessibilityText('编辑' + item.subject + '成绩')
                    .onClick(() => {
                      this.editScore(item);
                    })
                  Button('删除')
                    .height(38)
                    .fontSize(12)
                    .fontColor(AppConstants.COLOR_DANGER)
                    .backgroundColor('#14FF3B30')
                    .accessibilityText('删除' + item.subject + '成绩')
                    .onClick(() => {
                      this.confirmDelete(item);
                    })
                }
                .width('100%')
                .padding({ top: 9, bottom: 9 })
                .border({ width: { bottom: 1 }, color: AppConstants.COLOR_DIVIDER })
              }, (item: ExamScore) => item.id === undefined ? item.subject : item.id.toString())
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor(UiTokens.CARD_SOLID)
          .border({ width: 1, color: UiTokens.CARD_BORDER })
          .borderRadius(UiTokens.CARD_RADIUS)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 32 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppConstants.COLOR_BACKGROUND)
  }

  private focusSubject(): string {
    const item: ExamScore | undefined = this.focusScore();
    return item === undefined ? '待录入' : item.subject;
  }

  private strongestSubject(): string {
    const item: ExamScore | undefined = this.strongestScore();
    return item === undefined ? '待录入' : item.subject;
  }

  private focusAdvice(): string {
    const item: ExamScore | undefined = this.focusScore();
    return item === undefined ? '录入成绩后生成建议。' : this.scoreAdvice(item);
  }

  private insightCount(kind: number): number {
    let count: number = 0;
    for (let index: number = 0; index < this.scores.length; index++) {
      const value: number = this.ratio(this.scores[index]);
      if ((kind === 0 && value < 60) || (kind === 1 && value >= 60 && value < 85) ||
        (kind === 2 && value >= 85)) {
        count++;
      }
    }
    return count;
  }

  private insightSubjects(kind: number): string {
    const subjects: string[] = [];
    for (let index: number = 0; index < this.scores.length; index++) {
      const item: ExamScore = this.scores[index];
      const value: number = this.ratio(item);
      if ((kind === 0 && value < 60) || (kind === 1 && value >= 60 && value < 85) ||
        (kind === 2 && value >= 85)) {
        subjects.push(item.subject);
      }
    }
    return subjects.length === 0 ? '暂无符合条件的科目' : subjects.join('、');
  }

  private openInsight(kind: number): void {
    const titles: string[] = ['知识漏洞', '策略问题', '掌握良好'];
    const rules: string[] = ['得分率低于 60%', '得分率 60% - 84%', '得分率达到 85%'];
    const advice: string[] = [
      '先回到错题和基础概念，找出一个最常见的失分点，安排一次 20 分钟专项复习。',
      '知识基础已有一定积累，优先调整做题顺序、审题和时间分配，并复盘最近一次失分。',
      '保持当前方法，整理一页易错清单，把掌握住的经验迁移到相近题型。'
    ];
    this.getUIContext().getPromptAction().showDialog({
      title: titles[kind] + ' · ' + this.insightCount(kind).toString() + ' 门',
      message: rules[kind] + '\n涉及科目：' + this.insightSubjects(kind) + '\n\n' + advice[kind],
      buttons: [
        { text: '知道了', color: AppConstants.COLOR_PRIMARY }
      ]
    });
  }

  @Builder
  AnalysisHero() {
    Row({ space: 12 }) {
      Column({ space: 6 }) {
        Text('把结果变成下一步')
          .fontSize(21).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
        Text(this.scores.length === 0 ? '先记录一门成绩，开始你的复盘。' :
          '看清优势与短板，安排更有把握的复习。')
          .fontSize(12).fontColor(UiTokens.TEXT_SECONDARY).maxLines(2)
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($rawfile('kxq_ui_home_exam_calendar.png'))
        .width(76).height(70).objectFit(ImageFit.Contain)
    }
    .width('100%')
    .padding({ left: 16, right: 12, top: 14, bottom: 14 })
    .backgroundColor(UiTokens.CARD_SOLID)
    .border({ width: 1, color: UiTokens.CARD_BORDER })
    .borderRadius(UiTokens.HERO_RADIUS)
  }

  @Builder
  InsightCard(subjectName: string, title: string, advice: string) {
    Row({ space: 10 }) {
      Column()
        .width(6).height(44).borderRadius(3).backgroundColor('#FF9D4D')
      Column({ space: 3 }) {
        Text(title + ' · ' + subjectName)
          .fontSize(13).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
        Text(advice).fontSize(11).fontColor(UiTokens.TEXT_SECONDARY).maxLines(2)
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFF8F0')
    .border({ width: 1, color: '#FFE1C2' })
    .borderRadius(16)
  }

  @Builder
  InsightOverview() {
    Row({ space: 8 }) {
      this.InsightTag('知识漏洞', '低于 60%', 0, '#FFF1E6', '#C65D00')
      this.InsightTag('策略问题', '60% - 84%', 1, '#FFF8E1', '#9B7218')
      this.InsightTag('掌握良好', '85% 以上', 2, '#E8F8EE', '#14833B')
    }
    .width('100%')
    .height(94)
  }

  @Builder
  InsightTag(title: string, rule: string, kind: number, background: string, color: string) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 5 }) {
        Text(title)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(color)
          .maxLines(1)
        Text(this.insightCount(kind).toString() + ' 门')
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(UiTokens.TEXT_PRIMARY)
        Text(rule)
          .fontSize(10)
          .fontColor(UiTokens.TEXT_SECONDARY)
          .maxLines(1)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1)
    .height('100%')
    .padding(6)
    .backgroundColor(background)
    .border({ width: 1, color: color + '33' })
    .borderRadius(16)
    .accessibilityText(title + '，' + this.insightCount(kind).toString() + ' 门，点击查看建议')
    .onClick(() => {
      this.openInsight(kind);
    })
  }

}
