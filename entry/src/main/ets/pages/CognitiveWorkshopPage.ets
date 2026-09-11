import { router } from '@kit.ArkUI';
import { AppConstants, ThoughtChallenge } from '../common/DataModels';
import { DatabaseService } from '../services/DatabaseService';
import { HapticService } from '../services/HapticService';

@Entry
@Component
struct CognitiveWorkshopPage {
  @State viewportHeight: number = 760;
  @State viewportWidth: number = 390;
  @State step: number = 1;
  @State automaticThought: string = '';
  @State evidenceFor: string = '';
  @State evidenceAgainst: string = '';
  @State friendPerspective: string = '';
  @State balancedThought: string = '';
  @State saving: boolean = false;

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2200 });
  }

  private goBack(): void {
    if (this.step > 1) {
      this.step--;
      return;
    }
    router.back();
  }

  private nextStep(): void {
    if (this.automaticThought.trim().length === 0) {
      this.showToast('先写下此刻最困扰你的想法。');
      return;
    }
    if (this.step === 1 &&
      (this.evidenceFor.trim().length === 0 || this.evidenceAgainst.trim().length === 0)) {
      this.showToast('把支持和不支持这个想法的事实都写下来。');
      return;
    }
    if (this.step === 2 && this.friendPerspective.trim().length === 0) {
      this.showToast('试着写一句你会对朋友说的话。');
      return;
    }
    HapticService.light();
    this.step++;
  }

  private detectDistortion(text: string): string {
    if (text.includes('一定') || text.includes('完了') || text.includes('最差')) {
      return '灾难化';
    }
    if (text.includes('永远') || text.includes('每次') || text.includes('从来')) {
      return '过度概括';
    }
    if (text.includes('必须') || text.includes('要么')) {
      return '非黑即白';
    }
    return '自动化负面想法';
  }

  private answerValue(field: number): string {
    if (field === 1) {
      return this.evidenceFor;
    }
    if (field === 2) {
      return this.evidenceAgainst;
    }
    if (field === 3) {
      return this.friendPerspective;
    }
    return this.balancedThought;
  }

  private async saveThought(): Promise<void> {
    if (this.balancedThought.trim().length === 0 || this.saving) {
      this.showToast('先写下一句更真实、更温和的新想法。');
      return;
    }
    this.saving = true;
    try {
      const record: ThoughtChallenge = {
        negativeThought: this.automaticThought.trim(),
        alternativeThought: this.balancedThought.trim(),
        distortionType: this.detectDistortion(this.automaticThought),
        createdAt: new Date().toISOString()
      };
      await DatabaseService.addThoughtChallenge(record);
      HapticService.confirm();
      this.showToast('已保存到思维进化树。');
      router.back();
    } catch (reason) {
      this.showToast('保存没有完成，内容仍保留在这里。');
    } finally {
      this.saving = false;
    }
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#F8FBFF', 0.0], ['#EEF6FF', 0.55], ['#E9F3FF', 1.0]]
        })

      Column() {
        this.TopBar()
        Scroll() {
          Column({ space: 12 }) {
            this.StepHeading()
            if (this.step === 1) {
              this.EvidenceStep()
            } else if (this.step === 2) {
              this.PerspectiveStep()
            } else {
              this.BalancedStep()
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 16 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_old: Area, area: Area) => {
      this.viewportHeight = Number(area.height); this.viewportWidth = Number(area.width);
    })
  }

  @Builder
  TopBar() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Image($rawfile('back_arrow.svg')).width(24).height(24)
      }
      .width(44).height(44).accessibilityText('返回')
      .backgroundColor('#EFFFFFFF')
      .border({ width: 1, color: '#D8E6F7' })
      .onClick(() => {
        this.goBack();
      })
      Text('认知重构工坊')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#12365F')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text(this.step.toString() + ' / 3')
        .width(48)
        .fontSize(13)
        .fontColor('#6685A8')
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .height(66)
    .padding({ left: 16, right: 18, top: 8 })
  }

  @Builder
  StepHeading() {
    Row({ space: 16 }) {
      Text('0' + this.step.toString())
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#5B95E8')
      Column({ space: 4 }) {
        Text(this.step === 1 ? '找证据' : (this.step === 2 ? '换个角度' : '平衡想法'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#16365F')
        Text(this.step === 1 ? '看看想法背后的事实，会更清晰。' :
          (this.step === 2 ? '如果这是朋友遇到的事情，你会怎么安慰他？' :
            '把刚才的内容写成一句更真实、更温和的话。'))
          .fontSize(14)
          .fontColor('#5F7B9D')
          .maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  ThoughtInput() {
    Column({ space: 8 }) {
      Text('此刻最困扰我的想法')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#234B75')
      TextArea({ text: this.automaticThought, placeholder: '例如：我觉得这次一定会考砸。' })
        .width('100%')
        .height(64)
        .fontSize(15)
        .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
        .placeholderColor('#9AA8BA')
        .backgroundColor('#F4F8FF')
        .borderRadius(14)
        .padding(12)
        .onChange((value: string) => {
          this.automaticThought = value;
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#EAF3FF')
    .borderRadius(18)
  }

  @Builder
  EvidenceStep() {
    Column({ space: 12 }) {
      this.ThoughtInput()
      this.AnswerField('有什么事实支持这个想法？', '例如：最近两套模拟题成绩不理想…', 1, '#36A66F')
      this.AnswerField('有什么事实与它不一致？', '例如：我一直在坚持复习，也有进步过…', 2, '#DA8A2C')
      this.PrimaryAction('下一步：换个角度 >', () => {
        this.nextStep();
      })
    }
    .width('100%')
  }

  @Builder
  PerspectiveStep() {
    Column({ space: 12 }) {
      this.ThoughtPreview()
      this.AnswerField('写给“朋友”的一句话', '试着用你对朋友会说的语气写下来…', 3, '#5A95E8')
      this.PrimaryAction('下一步：形成平衡想法 >', () => {
        this.nextStep();
      })
    }
    .width('100%')
  }

  @Builder
  BalancedStep() {
    Column({ space: 12 }) {
      this.ThoughtPreview()
      this.AnswerField('我的新想法', '例如：我还有不会的内容，但我已经准备了很久，可以一步一步来。', 4, '#6A8D58')
      this.PrimaryAction(this.saving ? '正在保存…' : '保存到思维进化树', () => {
        this.saveThought();
      })
      Text('这一步不会评判对错，只是帮你看得更清楚。')
        .width('100%')
        .fontSize(12)
        .fontColor('#7C90A8')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
  }

  @Builder
  ThoughtPreview() {
    Text(this.automaticThought.length > 0 ? '“' + this.automaticThought + '”' : '先回到上一步，写下你的想法。')
      .width('100%')
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor('#234B75')
      .textAlign(TextAlign.Center)
      .maxLines(3)
      .padding(16)
      .backgroundColor('#EEF5FF')
      .borderRadius(18)
  }

  @Builder
  AnswerField(label: string, placeholder: string, field: number, color: string) {
    Column({ space: 9 }) {
      Text(label)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      TextArea({ text: this.answerValue(field), placeholder: placeholder })
        .width('100%')
        .height(Math.max(66, Math.min(120, (this.viewportHeight - 388) / 2)))
        .fontSize(15)
        .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
        .placeholderColor('#9AA8BA')
        .backgroundColor('#FFFFFFFF')
        .border({ width: 1, color: '#D8E6F7' })
        .borderRadius(18)
        .padding(14)
        .onChange((text: string) => {
          if (field === 1) {
            this.evidenceFor = text;
          } else if (field === 2) {
            this.evidenceAgainst = text;
          } else if (field === 3) {
            this.friendPerspective = text;
          } else {
            this.balancedThought = text;
          }
        })
    }
    .width('100%')
  }

  @Builder
  PrimaryAction(text: string, action: () => void) {
    Button(text)
      .width('100%')
      .height(46)
      .enabled(!this.saving)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor(AppConstants.COLOR_WHITE)
      .backgroundColor(this.saving ? '#9CB7D8' : '#2F80ED')
      .borderRadius(26)
      .onClick(action)
  }
}
