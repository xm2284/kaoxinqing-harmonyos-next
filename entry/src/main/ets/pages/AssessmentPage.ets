import {
  AppConstants,
  AssessmentRecord
} from '../common/DataModels';
import { router } from '@kit.ArkUI';
import { MemePopup } from '../common/MemePopup';
import { UiTokens } from '../common/UiTokens';
import { DatabaseService } from '../services/DatabaseService';
import { MemeService } from '../services/MemeService';

interface AssessmentContinuation {
  scaleType: string;
  questionIndex: number;
  answers: number[];
}

@Component
struct AssessmentGauge {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @Prop @Watch('redraw') score: number = 0;

  redraw(): void {
    this.draw();
  }

  private draw(): void {
    const ctx: CanvasRenderingContext2D = this.context;
    const cx: number = 100;
    const cy: number = 100;
    const radius: number = 72;
    ctx.clearRect(0, 0, 200, 130);
    const colors: string[] = [
      AppConstants.COLOR_STRESS_LOW,
      AppConstants.COLOR_STRESS_MID_LOW,
      AppConstants.COLOR_STRESS_MID_HIGH,
      AppConstants.COLOR_STRESS_HIGH
    ];
    for (let segment: number = 0; segment < 4; segment++) {
      ctx.beginPath();
      ctx.arc(cx, cy, radius, Math.PI + segment * Math.PI / 4,
        Math.PI + (segment + 1) * Math.PI / 4);
      ctx.strokeStyle = colors[segment];
      ctx.lineWidth = 12;
      ctx.stroke();
    }
    for (let tick: number = 0; tick <= 50; tick++) {
      const angle: number = Math.PI + Math.PI * tick / 50;
      const outer: number = radius + 11;
      const inner: number = tick % 5 === 0 ? radius + 1 : radius + 5;
      ctx.beginPath();
      ctx.moveTo(cx + Math.cos(angle) * inner, cy + Math.sin(angle) * inner);
      ctx.lineTo(cx + Math.cos(angle) * outer, cy + Math.sin(angle) * outer);
      ctx.strokeStyle = tick % 5 === 0 ? '#88555666' : '#448899AA';
      ctx.lineWidth = tick % 5 === 0 ? 2 : 1;
      ctx.stroke();
    }
    const needle: number = Math.PI + Math.PI * Math.max(0, Math.min(10, this.score)) / 10;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.lineTo(cx + Math.cos(needle) * 54, cy + Math.sin(needle) * 54);
    ctx.strokeStyle = AppConstants.COLOR_TEXT_PRIMARY;
    ctx.lineWidth = 3;
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(cx, cy, 5, 0, Math.PI * 2);
    ctx.fillStyle = AppConstants.COLOR_TEXT_PRIMARY;
    ctx.fill();
    ctx.fillStyle = AppConstants.COLOR_TEXT_PRIMARY;
    ctx.font = 'bold 20px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(this.score.toFixed(1), cx, 124);
  }

  build() {
    Canvas(this.context)
      .width(200)
      .height(130)
      .onReady(() => {
        this.draw();
      })
  }
}

@Component
export struct AssessmentPage {
  @State history: AssessmentRecord[] = [];
  @State running: boolean = false;
  @State scaleType: string = 'GAD-7';
  @State questionIndex: number = 0;
  @State answers: number[] = [];
  @State selectedAnswer: number = -1;
  @State resultScore: number = -1;
  @State editingId: number = -1;
  @State showMeme: boolean = false;
  @State memeAsset: string = 'daily_1';
  @State memeMessage: string = '';

  aboutToAppear(): void {
    this.loadHistory();
    this.restoreProgress();
  }

  private restoreProgress(): void {
    const saved: string = AppStorage.get<string>('currentAssessment') ?? '';
    if (saved.length === 0) {
      return;
    }
    try {
      const progress: AssessmentContinuation = JSON.parse(saved) as AssessmentContinuation;
      this.scaleType = progress.scaleType;
      this.questionIndex = progress.questionIndex;
      this.answers = progress.answers;
      this.selectedAnswer = this.answers.length > this.questionIndex ?
        this.answers[this.questionIndex] : -1;
    } catch (reason) {
      AppStorage.setOrCreate('currentAssessment', '');
    }
  }

  private saveProgress(): void {
    const progress: AssessmentContinuation = {
      scaleType: this.scaleType,
      questionIndex: this.questionIndex,
      answers: this.answers
    };
    AppStorage.setOrCreate('currentAssessment', JSON.stringify(progress));
  }

  private async loadHistory(): Promise<void> {
    try {
      this.history = await DatabaseService.getAllAssessments();
      if (this.history.length > 0) {
        this.resultScore = this.history[0].stressLevel;
      }
    } catch (reason) {
      this.showToast('测评记录暂时没有加载出来。');
    }
  }

  private questions(): string[] {
    return this.scaleType === 'SAS' ? AppConstants.SAS_QUESTIONS : AppConstants.GAD7_QUESTIONS;
  }

  private start(type: string): void {
    this.scaleType = type;
    this.questionIndex = 0;
    this.answers = [];
    this.selectedAnswer = -1;
    this.editingId = -1;
    this.running = true;
    this.saveProgress();
  }

  private edit(record: AssessmentRecord): void {
    this.scaleType = record.type;
    this.answers = record.answers.slice();
    this.questionIndex = 0;
    this.selectedAnswer = this.answers.length > 0 ? this.answers[0] : -1;
    this.editingId = record.id === undefined ? -1 : record.id;
    this.running = true;
    this.saveProgress();
  }

  private chooseAnswer(answer: number): void {
    this.selectedAnswer = answer;
  }

  private previousQuestion(): void {
    if (this.questionIndex <= 0) {
      return;
    }
    this.questionIndex--;
    this.selectedAnswer = this.answers.length > this.questionIndex ?
      this.answers[this.questionIndex] : -1;
    this.saveProgress();
  }

  private async nextQuestion(): Promise<void> {
    if (this.selectedAnswer < 0) {
      this.showToast('请选择最符合近两周感受的一项。');
      return;
    }
    const updated: number[] = this.answers.slice();
    updated[this.questionIndex] = this.selectedAnswer;
    this.answers = updated;
    if (this.questionIndex < this.questions().length - 1) {
      this.questionIndex++;
      this.selectedAnswer = this.answers.length > this.questionIndex ?
        this.answers[this.questionIndex] : -1;
      if (this.questionIndex > 0 && this.questionIndex % 5 === 0) {
        this.showToast('已经完成一大半了，按真实感受选择就好。');
      }
      this.saveProgress();
      return;
    }
    await this.finishAssessment();
  }

  private async finishAssessment(): Promise<void> {
    let total: number = 0;
    for (let index: number = 0; index < this.answers.length; index++) {
      total += this.answers[index];
    }
    const maxScore: number = this.questions().length * 3;
    const stress: number = maxScore === 0 ? 0 : total / maxScore * 10;
    const record: AssessmentRecord = {
      date: new Date().toISOString(),
      type: this.scaleType,
      answers: this.answers,
      totalScore: total,
      stressLevel: Number(stress.toFixed(1))
    };
    try {
      if (this.editingId > 0) {
        record.id = this.editingId;
        await DatabaseService.updateAssessment(record);
      } else {
        await DatabaseService.addAssessment(record);
      }
      this.resultScore = record.stressLevel;
      AppStorage.setOrCreate('pressureLevel', record.stressLevel);
      AppStorage.setOrCreate('currentAssessment', '');
      await this.loadHistory();
      this.running = false;
      await this.showResultMeme(record.stressLevel);
      this.showToast(this.resultMessage(record.stressLevel));
    } catch (reason) {
      this.showToast('测评结果没有保存成功，答案还为你保留着。');
    }
  }

  private async showResultMeme(score: number): Promise<void> {
    if (!await MemeService.shouldShow('assessment_result')) {
      return;
    }
    if (score <= 3) {
      this.memeAsset = 'daily_1';
      this.memeMessage = '状态不错！继续保持今天的节奏。';
    } else if (score <= 6) {
      this.memeAsset = 'daily_3';
      this.memeMessage = '有点焦虑很正常，你已经在面对它了。';
    } else {
      this.memeAsset = 'breakdown';
      this.memeMessage = '压力不小，先休息一下，或者找小晴。';
    }
    this.showMeme = true;
  }

  private resultMessage(score: number): string {
    if (score <= 3) {
      return '状态不错，继续保持现在的节奏。';
    }
    if (score <= 6) {
      return '有点焦虑很正常，你已经在认真面对它了。';
    }
    return '压力不小，可以先去放松训练，或找小晴。';
  }

  private confirmExit(): void {
    this.getUIContext().getPromptAction().showDialog({
      title: '测评还没做完',
      message: '确定要退出吗？已完成的答案会暂时保留在本页。',
      buttons: [
        { text: '继续答题', color: AppConstants.COLOR_PRIMARY },
        { text: '退出', color: AppConstants.COLOR_DANGER }
      ]
    }).then((result) => {
      if (result.index === 1) {
        this.running = false;
      }
    });
  }

  private confirmDelete(record: AssessmentRecord): void {
    if (record.id === undefined) {
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: '删除测评记录',
      message: '这条记录删除后无法恢复，确定吗？',
      buttons: [
        { text: '保留', color: AppConstants.COLOR_TEXT_SECONDARY },
        { text: '删除', color: AppConstants.COLOR_DANGER }
      ]
    }).then((result) => {
      if (result.index === 1 && record.id !== undefined) {
        this.deleteRecord(record.id);
      }
    });
  }

  private async deleteRecord(id: number): Promise<void> {
    try {
      await DatabaseService.deleteAssessment(id);
      await this.loadHistory();
      this.showToast('测评记录已删除。');
    } catch (reason) {
      this.showToast('刚才没有删除成功，再试一次？');
    }
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2500 });
  }

  private leavePage(): void {
    router.back();
  }

  build() {
    Stack() {
      Column() {
        this.AssessmentTopBar()
        Scroll() {
          Column({ space: 14 }) {
            this.AssessmentIntro()
            Row() {
              Text('选择量表').fontSize(16).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
              Blank()
              Text('按近两周感受作答').fontSize(11).fontColor(UiTokens.TEXT_SECONDARY)
            }
            .width('100%')
            Row({ space: 12 }) {
              this.ScaleCard('GAD-7', '7 题', '快速了解近两周焦虑状态', '轻量、适合第一次测评')
              this.ScaleCard('SAS', '20 题', '更完整地观察身心反应', '需要更多时间完成')
            }
            .width('100%')

            if (this.resultScore >= 0) {
              this.ResultCard()
            }

            Text('量表用于自我了解，不替代专业诊断。请按近两周的真实感受作答。')
              .width('100%')
              .fontSize(11)
              .fontColor(UiTokens.TEXT_MUTED)
              .lineHeight(17)

            this.HistorySection()
          }
          .width('100%')
          .constraintSize({ maxWidth: 680 })
          .padding({ left: 16, right: 16, bottom: 20 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .bindContentCover($$this.running, this.AssessmentCover(), {
        modalTransition: ModalTransition.DEFAULT
      })
      if (this.showMeme) {
        MemePopup({
          visible: $showMeme,
          asset: this.memeAsset,
          message: this.memeMessage
        })
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 135, colors: [[UiTokens.PAGE_BG_TOP, 0.0], [UiTokens.PAGE_BG_BOTTOM, 1.0]] })
  }

  @Builder
  AssessmentTopBar() {
    Row({ space: 12 }) {
      Button({ type: ButtonType.Circle }) {
        Image($rawfile('back_arrow.svg')).width(22).height(22)
      }
      .width(44).height(44)
      .accessibilityText('返回首页')
      .backgroundColor(UiTokens.CARD_SOLID)
      .border({ width: 1, color: UiTokens.CARD_BORDER })
      .onClick(() => { this.leavePage(); })

      Column({ space: 2 }) {
        Text('心情测评')
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(UiTokens.TEXT_PRIMARY)
        Text('花几分钟，听听最近的自己')
          .fontSize(12)
          .fontColor(UiTokens.TEXT_SECONDARY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 10 })
  }

  @Builder
  AssessmentIntro() {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Column({ space: 6 }) {
          Text('今天的状态，值得被看见')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.TEXT_PRIMARY)
          Text('选择一份适合你的量表，按真实感受完成即可。')
            .fontSize(12)
            .fontColor(UiTokens.TEXT_SECONDARY)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Image($rawfile('kxq_ui_cog_brain_header.png'))
          .width(70).height(64).objectFit(ImageFit.Contain)
      }
      .width('100%')
      Row({ space: 8 }) {
        this.IntroTag('2 份量表')
        this.IntroTag('近两周状态')
        this.IntroTag('约 3-5 分钟')
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 12, top: 15, bottom: 15 })
    .backgroundColor(UiTokens.CARD_SOLID)
    .border({ width: 1, color: UiTokens.CARD_BORDER })
    .borderRadius(UiTokens.HERO_RADIUS)
  }

  @Builder
  IntroTag(label: string) {
    Text(label)
      .fontSize(10)
      .fontColor(UiTokens.PRIMARY)
      .padding({ left: 9, right: 9, top: 5, bottom: 5 })
      .backgroundColor(UiTokens.SURFACE_BLUE)
      .borderRadius(10)
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
  }

  @Builder
  ResultCard() {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text('最近一次结果').fontSize(12).fontColor(UiTokens.TEXT_SECONDARY)
        Text(AppConstants.getStressLabel(this.resultScore))
          .fontSize(17).fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.getStressColor(this.resultScore))
        Text(this.resultMessage(this.resultScore)).fontSize(11).fontColor(UiTokens.TEXT_SECONDARY)
          .maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      AssessmentGauge({ score: this.resultScore })
    }
    .width('100%')
    .padding({ left: 16, right: 12, top: 12, bottom: 8 })
    .backgroundColor(UiTokens.SURFACE_BLUE)
    .border({ width: 1, color: '#CFE2FF' })
    .borderRadius(UiTokens.CARD_RADIUS)
  }

  @Builder
  HistorySection() {
    Column({ space: 10 }) {
      Row() {
        Text('历史记录').fontSize(16).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
        Blank()
        Text(this.history.length.toString() + ' 次').fontSize(11).fontColor(UiTokens.TEXT_MUTED)
      }
      .width('100%')
      if (this.history.length === 0) {
        Row({ space: 10 }) {
          Image($rawfile('kxq_mood_neutral.png')).width(34).height(34)
          Text('还没有测评记录，完成一次就能看到自己的变化。')
            .fontSize(12).fontColor(UiTokens.TEXT_SECONDARY).layoutWeight(1)
        }
        .width('100%').padding(14).backgroundColor('#AAFFFFFF').borderRadius(16)
      } else {
        ForEach(this.history.slice(0, 5), (item: AssessmentRecord) => {
          Row({ space: 10 }) {
            Column({ space: 3 }) {
              Text(item.type + ' · ' + item.stressLevel.toFixed(1))
                .fontSize(14).fontWeight(FontWeight.Medium).fontColor(UiTokens.TEXT_PRIMARY)
              Text(item.date.substring(0, 10) + ' · ' + AppConstants.getStressLabel(item.stressLevel))
                .fontSize(11).fontColor(UiTokens.TEXT_MUTED)
            }
            .alignItems(HorizontalAlign.Start).layoutWeight(1)
            Button('重做').height(34).fontSize(11).fontColor(UiTokens.PRIMARY)
              .backgroundColor('#1A2F80FF').onClick(() => { this.edit(item); })
            Button('删除').height(34).fontSize(11).fontColor(UiTokens.DANGER)
              .backgroundColor('#16FF8B84').onClick(() => { this.confirmDelete(item); })
          }
          .width('100%').padding({ top: 10, bottom: 10 })
          .backgroundColor('#AAFFFFFF').borderRadius(14)
        }, (item: AssessmentRecord) => item.id === undefined ? item.date : item.id.toString())
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ScaleCard(type: string, count: string, description: string, hint: string) {
    Column({ space: 7 }) {
      Row() {
        Text(type)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(UiTokens.PRIMARY)
        Blank()
        Text(count)
          .fontSize(11)
          .fontColor(UiTokens.TEXT_MUTED)
      }
      .width('100%')
      Text(description)
        .width('100%')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(UiTokens.TEXT_PRIMARY)
        .maxLines(2)
      Text(hint)
        .width('100%')
        .fontSize(10)
        .fontColor(UiTokens.TEXT_SECONDARY)
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(122)
    .justifyContent(FlexAlign.Start)
    .padding({ left: 14, right: 14, top: 14, bottom: 12 })
    .backgroundColor(UiTokens.CARD_SOLID)
    .border({ width: 1, color: UiTokens.CARD_BORDER })
    .borderRadius(UiTokens.CARD_RADIUS)
    .accessibilityText('开始 ' + type + ' 测评，' + description)
    .onClick(() => {
      this.showToast(type + ' 测评已开始');
      this.start(type);
    })
  }

  @Builder
  AssessmentCover() {
    Column() {
      Row({ space: 10 }) {
        Button({ type: ButtonType.Circle }) {
          Image($rawfile('back_arrow.svg')).width(22).height(22)
        }
        .width(44).height(44)
        .accessibilityText('退出测评')
        .backgroundColor(UiTokens.CARD_SOLID)
        .border({ width: 1, color: UiTokens.CARD_BORDER })
        .onClick(() => { this.confirmExit(); })
        Column({ space: 2 }) {
          Text(this.scaleType + ' 测评')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.TEXT_PRIMARY)
          Text('按近两周的真实感受作答')
            .fontSize(11)
            .fontColor(UiTokens.TEXT_SECONDARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text((this.questionIndex + 1).toString() + '/' + this.questions().length.toString())
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.PRIMARY)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 10 })

      Column({ space: 14 }) {
        Progress({
          value: this.questionIndex + 1,
          total: this.questions().length,
          type: ProgressType.Linear
        })
          .width('100%')
          .height(7)
          .color(UiTokens.PRIMARY)
        Text('这一题没有标准答案，选择最接近你的选项。')
          .width('100%')
          .fontSize(12)
          .fontColor(UiTokens.TEXT_SECONDARY)
        Column({ space: 10 }) {
          Text('第 ' + (this.questionIndex + 1).toString() + ' 题')
            .width('100%')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(UiTokens.PRIMARY)
          Text(this.questions()[this.questionIndex])
            .width('100%')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(UiTokens.TEXT_PRIMARY)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        .backgroundColor(UiTokens.CARD_SOLID)
        .border({ width: 1, color: UiTokens.CARD_BORDER })
        .borderRadius(UiTokens.CARD_RADIUS)

        Column({ space: 9 }) {
          ForEach(AppConstants.SCALE_OPTIONS, (option: string, index: number) => {
            Row({ space: 12 }) {
              Radio({ value: index.toString(), group: 'assessmentAnswer' })
                .checked(this.selectedAnswer === index)
                .onChange(() => { this.chooseAnswer(index); })
              Text(option)
                .fontSize(15)
                .fontColor(UiTokens.TEXT_PRIMARY)
                .layoutWeight(1)
              if (this.selectedAnswer === index) {
                Text('已选').fontSize(11).fontColor(UiTokens.PRIMARY)
              }
            }
            .width('100%')
            .height(56)
            .padding({ left: 14, right: 14 })
            .backgroundColor(this.selectedAnswer === index ? '#EAF4FF' : UiTokens.CARD_SOLID)
            .border({ width: 1, color: this.selectedAnswer === index ? UiTokens.PRIMARY : UiTokens.CARD_BORDER })
            .borderRadius(16)
            .onClick(() => { this.chooseAnswer(index); })
          }, (option: string) => option)
        }
        .width('100%')

        Row({ space: 10 }) {
          if (this.questionIndex > 0) {
            Button('上一题')
              .width(92)
              .height(50)
              .fontSize(14)
              .fontColor(UiTokens.PRIMARY)
              .backgroundColor(UiTokens.CARD_SOLID)
              .border({ width: 1, color: UiTokens.CARD_BORDER })
              .borderRadius(16)
              .onClick(() => { this.previousQuestion(); })
          }
          Button(this.questionIndex === this.questions().length - 1 ? '查看结果' : '下一题')
            .layoutWeight(1)
            .height(50)
            .enabled(this.selectedAnswer >= 0)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor(this.selectedAnswer >= 0 ? UiTokens.PRIMARY : '#C8D1DD')
            .borderRadius(16)
            .onClick(() => { this.nextQuestion(); })
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16, top: 8, bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(UiTokens.PAGE_BG_BOTTOM)
  }
}
