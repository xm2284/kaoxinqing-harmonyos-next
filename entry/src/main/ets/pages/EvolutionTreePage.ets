import { AppConstants, ThoughtChallenge } from '../common/DataModels';
import { DatabaseService } from '../services/DatabaseService';
import { HapticService } from '../services/HapticService';

@Entry
@Component
struct EvolutionTreePage {
  @State viewportHeight: number = 760;
  @State viewportWidth: number = 390;
  @State records: ThoughtChallenge[] = [];
  @State timelineExpanded: boolean = false;
  @State selectedRecordId: number = -1;
  @State editVisible: boolean = false;
  @State editingRecord: ThoughtChallenge | undefined = undefined;
  @State editingThought: string = '';

  aboutToAppear(): void {
    this.loadRecords();
  }

  private async loadRecords(): Promise<void> {
    try {
      this.records = await DatabaseService.getAllThoughtChallenges();
    } catch (reason) {
      this.showToast('成长记录暂时没有加载出来。');
    }
  }

  private completedStages(): number {
    return Math.min(3, this.records.length);
  }

  private extraRecords(): ThoughtChallenge[] {
    const items: ThoughtChallenge[] = [];
    for (let index: number = 3; index < this.records.length; index++) {
      items.push(this.records[index]);
    }
    return items;
  }

  private stageTitle(index: number): string {
    if (index === 0) {
      return '萌芽';
    }
    if (index === 1) {
      return '生长';
    }
    return '开花';
  }

  private stageDetail(index: number): string {
    if (index === 0) {
      return '第一步，总是最有力量的';
    }
    if (index === 1) {
      return '换个角度，世界也会不一样';
    }
    return '看见成长，也看见更好的自己';
  }

  private stageRecord(index: number): ThoughtChallenge | undefined {
    const recordIndex: number = this.records.length - 1 - index;
    if (recordIndex < 0 || recordIndex >= this.records.length) {
      return undefined;
    }
    return this.records[recordIndex];
  }

  private formatDate(value: string): string {
    const date: Date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      return '今天';
    }
    const month: string = (date.getMonth() + 1).toString().padStart(2, '0');
    const day: string = date.getDate().toString().padStart(2, '0');
    return date.getFullYear().toString() + '.' + month + '.' + day;
  }

  private currentRecord(): ThoughtChallenge | undefined {
    if (this.selectedRecordId < 0) {
      return this.records.length > 0 ? this.records[0] : undefined;
    }
    for (let index: number = 0; index < this.records.length; index++) {
      if (this.records[index].id === this.selectedRecordId) {
        return this.records[index];
      }
    }
    return this.records.length > 0 ? this.records[0] : undefined;
  }

  private selectRecord(item: ThoughtChallenge): void {
    this.selectedRecordId = item.id === undefined ? -1 : item.id;
    HapticService.light();
  }

  private openEditor(item: ThoughtChallenge): void {
    this.editingRecord = item;
    this.editingThought = item.alternativeThought;
    this.editVisible = true;
  }

  private closeEditor(): void {
    this.editVisible = false;
    this.editingRecord = undefined;
    this.editingThought = '';
  }

  private async saveEdit(): Promise<void> {
    if (this.editingRecord === undefined || this.editingRecord.id === undefined ||
      this.editingThought.trim().length === 0) {
      this.showToast('平衡思维不能为空。');
      return;
    }
    this.editingRecord.alternativeThought = this.editingThought.trim();
    try {
      await DatabaseService.updateThoughtChallenge(this.editingRecord);
      this.closeEditor();
      await this.loadRecords();
      this.showToast('成长记录已更新。');
    } catch (reason) {
      this.showToast('刚才没有保存成功，内容还保留着。');
    }
  }

  private confirmDelete(item: ThoughtChallenge): void {
    if (item.id === undefined) {
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: '删除成长记录',
      message: '删除后无法恢复，确定要删除这条平衡思维吗？',
      buttons: [
        { text: '保留', color: AppConstants.COLOR_TEXT_SECONDARY },
        { text: '删除', color: AppConstants.COLOR_DANGER }
      ]
    }).then((result) => {
      if (result.index === 1 && item.id !== undefined) {
        this.deleteRecord(item.id);
      }
    });
  }

  private async deleteRecord(id: number): Promise<void> {
    try {
      await DatabaseService.deleteThoughtChallenge(id);
      if (this.selectedRecordId === id) {
        this.selectedRecordId = -1;
      }
      await this.loadRecords();
      this.showToast('成长记录已删除。');
    } catch (reason) {
      this.showToast('刚才没有删除成功，再试一次？');
    }
  }

  private openWorkshop(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CognitiveWorkshopPage' }).catch(() => {
      this.showToast('认知重构工坊暂时没有打开，再试一次？');
    });
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2200 });
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#D9F0FF', 0.0], ['#ECF9FF', 0.48], ['#DDF4DA', 1.0]]
        })

      Image($rawfile('kxq_breath_lake_scene.png'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(0.13)

      Image($rawfile('kxq_rest_hero_tree_bench.png'))
        .width('122%')
        .height(590)
        .objectFit(ImageFit.Contain)
        .opacity(0.09)
        .align(Alignment.Bottom)
        .margin({ bottom: -80, left: -100 })

      Image($rawfile('kxq_ui_rest_reference_branch.png'))
        .width(220)
        .height(126)
        .objectFit(ImageFit.Contain)
        .opacity(0.5)
        .align(Alignment.TopEnd)
        .margin({ top: 112, right: -36 })

      Image($rawfile('kxq_ref_evolution_leaf.png'))
        .width(46)
        .height(50)
        .objectFit(ImageFit.Contain)
        .opacity(0.58)
        .align(Alignment.TopEnd)
        .margin({ top: 168, right: 52 })

      Column() {
        this.TopBar()
        Scroll() {
          Column({ space: 0 }) {
            this.EvolutionTimeline()
            this.ReflectionCard()
            this.ActionBar()
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')

      if (this.editVisible) {
        this.EditorSheet()
      }
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
      .border({ width: 1, color: '#D7EAF7' })
      .shadow({ radius: 12, color: '#246EA51A', offsetY: 4 })
      .onClick(() => {
        this.getUIContext().getRouter().back();
      })

      Text('思维进化树')
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor('#163E6B')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Button() {
        Row({ space: 7 }) {
          Text('▣')
            .fontSize(19)
            .fontColor('#24588D')
          Text('时间轴')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#24588D')
        }
        .justifyContent(FlexAlign.Center)
      }
      .width(112)
      .height(44)
      .backgroundColor('#CFFFFFFF')
      .border({ width: 1, color: '#CEE4F4' })
      .borderRadius(24)
      .shadow({ radius: 10, color: '#246EA514', offsetY: 3 })
      .onClick(() => {
        this.timelineExpanded = !this.timelineExpanded;
      })
    }
    .width('100%')
    .height(62)
    .padding({ left: 20, right: 20, top: 14 })
  }

  @Builder
  EvolutionTimeline() {
    Column({ space: 0 }) {
      if (this.records.length === 0) {
        this.EmptyTree()
      } else {
        this.TreeStage(2)
        this.TreeStage(1)
        this.TreeStage(0)
      }

      if (this.timelineExpanded && this.records.length > 3) {
        this.RecordHistory()
      }
    }
    .width('100%')
    .padding({ top: 8 })
  }

  @Builder
  EmptyTree() {
    Column({ space: 12 }) {
      Image($rawfile('kxq_scene_tree.png'))
        .width(120)
        .height(120)
        .objectFit(ImageFit.Contain)
        .opacity(0.9)
      Text('种下一条新的平衡思维')
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor('#245785')
      Text('完成一次认知重构，进化树就会长出第一片叶子。')
        .fontSize(14)
        .fontColor('#64839D')
        .textAlign(TextAlign.Center)
      Button('去认知重构')
        .height(46)
        .fontSize(16)
        .fontColor('#FFFFFFFF')
        .backgroundColor('#4C9E73')
        .borderRadius(23)
        .padding({ left: 24, right: 24 })
        .onClick(() => {
          this.openWorkshop();
        })
    }
    .width('100%')
    .padding({ top: 12, bottom: 16, left: 16, right: 16 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  TreeStage(index: number) {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(78)
          .height(88)
          .backgroundColor('#F7FFFFFF')
          .border({ width: 1, color: '#9FD9C1' })
          .borderRadius(index === 2 ? 84 : 77)
          .shadow({ radius: 14, color: '#4D8A6E2B', offsetY: 5 })
        if (index === 2) {
          Image($rawfile('kxq_ui_evolution_blossom.png'))
            .width(76)
            .height(86)
            .objectFit(ImageFit.Contain)
            .opacity(this.stageRecord(index) !== undefined ? 1 : 0.94)
        } else if (index === 1) {
          Image($rawfile('kxq_ui_evolution_sprout.png'))
            .width(76)
            .height(86)
            .objectFit(ImageFit.Contain)
            .opacity(this.stageRecord(index) !== undefined ? 1 : 0.95)
        } else {
          Image($rawfile('kxq_ui_evolution_seedling.png'))
            .width(76)
            .height(86)
            .objectFit(ImageFit.Contain)
            .opacity(this.stageRecord(index) !== undefined ? 1 : 0.96)
        }
      }
      .width(86)
      .height(96)

      this.StageCard(index, this.stageRecord(index))
    }
    .width('100%')
    .height(Math.max(106, Math.min(132, this.viewportHeight * 0.16)))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  StageCard(index: number, record: ThoughtChallenge | undefined) {
    Column({ space: 4 }) {
      Row() {
        Text(this.stageTitle(index))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(index === 2 ? '#A3515B' : '#2C7554')
          .padding({ left: 14, right: 14, top: 5, bottom: 5 })
          .backgroundColor(index === 2 ? '#FCE8EC' : '#E4F1DB')
          .borderRadius(16)
        Blank()
        if (record !== undefined) {
          Text('✓')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFFFF')
            .width(34)
            .height(34)
            .textAlign(TextAlign.Center)
            .padding({ top: 3 })
            .backgroundColor(index === 2 ? '#ED98A7' : '#8DBC72')
            .borderRadius(18)
        }
      }
      .width('100%')
      Text(record === undefined ? '完成一次认知重构，点亮这一阶段。' :
        (record.alternativeThought.length > 20 ? record.alternativeThought.slice(0, 20) + '...' : record.alternativeThought))
        .width('100%')
        .fontSize(13)
        .lineHeight(18)
        .fontColor('#173F6C')
        .maxLines(2)
      Text(record === undefined ? '等待点亮' : this.formatDate(record.createdAt) + ' 点亮')
        .fontSize(11)
        .fontColor(index === 2 ? '#C57983' : '#5E966A')
    }
    .layoutWeight(1)
    .height(100)
    .padding(10)
    .backgroundColor(record === undefined ? '#AFFFFFFF' : '#DFFFFFFF')
    .border({ width: 1, color: '#D8EAF6' })
    .borderRadius(24)
    .shadow({ radius: 16, color: '#1B5D8E17', offsetY: 6 })
    .onClick(() => {
      if (record !== undefined) {
        this.selectRecord(record);
      } else {
        this.openWorkshop();
      }
    })
  }

  @Builder
  RecordHistory() {
    Column({ space: 10 }) {
      Row() {
        Text('更多成长足迹')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#245785')
          .layoutWeight(1)
        Text(this.extraRecords().length.toString() + ' 条')
          .fontSize(13)
          .fontColor('#7897AF')
      }
      .width('100%')
      .padding({ bottom: 3 })

      ForEach(this.extraRecords(), (item: ThoughtChallenge) => {
        Row({ space: 12 }) {
          Column()
            .width(10)
            .height(10)
            .borderRadius(5)
            .backgroundColor('#86B96D')
            .margin({ left: 4 })
          Column({ space: 4 }) {
            Text(item.alternativeThought)
              .width('100%')
              .fontSize(15)
              .fontColor('#173F6C')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.formatDate(item.createdAt) + ' · ' + item.distortionType)
              .fontSize(12)
              .fontColor('#7897AF')
          }
          .layoutWeight(1)
          Text('›')
            .fontSize(24)
            .fontColor('#8AA6BD')
        }
        .width('100%')
        .height(62)
        .padding({ left: 12, right: 12 })
        .backgroundColor('#CFFFFFFF')
        .border({ width: 1, color: '#DCEBF5' })
        .borderRadius(16)
        .onClick(() => {
          this.selectRecord(item);
        })
      }, (item: ThoughtChallenge) => item.id === undefined ? item.createdAt : item.id.toString())
    }
    .width('100%')
    .padding({ top: 14, left: 8, right: 8, bottom: 4 })
  }

  @Builder
  ReflectionCard() {
    Column({ space: 6 }) {
      Row() {
        Text(this.currentRecord() === undefined ? '新的成长正在路上' :
          this.formatDate(this.currentRecord()!.createdAt).replace('.', '月').replace('.', '日'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#173F6C')
          .layoutWeight(1)
        if (this.currentRecord() !== undefined) {
          Button() {
            Row({ space: 5 }) {
              Text('✎')
                .fontSize(15)
              Text('编辑')
                .fontSize(14)
            }
            .justifyContent(FlexAlign.Center)
          }
          .height(34)
          .fontColor('#4079C0')
          .backgroundColor('#E9F2FE')
          .borderRadius(18)
          .padding({ left: 13, right: 13 })
          .onClick(() => {
            const selected: ThoughtChallenge | undefined = this.currentRecord();
            if (selected !== undefined) {
              this.openEditor(selected);
            }
          })
        }
      }
      .width('100%')
      .padding({ bottom: 9 })
      .border({ width: { bottom: 1 }, color: '#D8E6F1' })

      Text(this.currentRecord() === undefined ? '不必一下看到终点，先完成眼前这一小步。' :
        this.currentRecord()!.alternativeThought)
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .lineHeight(21)
        .fontColor('#173F6C')
        .textAlign(TextAlign.Center)
        .maxLines(3)
      Row({ space: 7 }) {
        Text('●')
          .fontSize(14)
          .fontColor('#83B55F')
        Text(this.currentRecord() === undefined ? '来自 思维进化树' :
          '来自 认知重构工坊 · ' + this.currentRecord()!.distortionType)
          .fontSize(13)
          .fontColor('#7791AA')
      }
    }
    .width('100%')
    .padding(12)
    .margin({ top: 10 })
    .backgroundColor('#EFFFFFFF')
    .border({ width: 1, color: '#E0ECF5' })
    .borderRadius(26)
    .shadow({ radius: 18, color: '#1B5D8E1A', offsetY: 7 })
  }

  @Builder
  ActionBar() {
    Row() {
      this.ActionItem('▤', '全部记录', () => {
        this.timelineExpanded = !this.timelineExpanded;
      })
      this.ActionItem('✎', '编辑树', () => {
        const record: ThoughtChallenge | undefined = this.currentRecord();
        if (record !== undefined) {
          this.openEditor(record);
        } else {
          this.openWorkshop();
        }
      })
      this.ActionItem('⌫', '删除记录', () => {
        const record: ThoughtChallenge | undefined = this.currentRecord();
        if (record !== undefined) {
          this.confirmDelete(record);
        }
      })
    }
    .width('100%')
    .height(82)
    .margin({ top: 20 })
    .justifyContent(FlexAlign.SpaceEvenly)
    .backgroundColor('#EFFFFFFF')
    .border({ width: 1, color: '#D8EAF4' })
    .borderRadius(24)
    .shadow({ radius: 14, color: '#1B5D8E14', offsetY: 5 })
  }

  @Builder
  ActionItem(icon: string, label: string, action: () => void) {
    Column({ space: 6 }) {
      Text(icon)
        .fontSize(27)
        .fontColor('#5F87A9')
      Text(label)
        .fontSize(13)
        .fontColor('#5F87A9')
    }
    .width(86)
    .height(68)
    .justifyContent(FlexAlign.Center)
    .onClick(action)
  }

  @Builder
  EditorSheet() {
    Column() {
      Blank()
        .layoutWeight(1)
        .width('100%')
        .backgroundColor('#550C3154')
        .onClick(() => {
          this.closeEditor();
        })
      Column({ space: 16 }) {
        Row() {
          Text('编辑平衡思维')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#173F6C')
            .layoutWeight(1)
          Button({ type: ButtonType.Circle }) {
            Text('×')
              .fontSize(25)
              .fontColor('#5D7E99')
          }
          .width(38)
          .height(38)
          .backgroundColor('#EAF3F9')
          .onClick(() => {
            this.closeEditor();
          })
        }
        .width('100%')
        TextArea({ text: this.editingThought, placeholder: '写下更公平、更能行动的想法' })
          .width('100%')
          .height(118)
          .fontSize(16)
          .fontColor('#173F6C')
          .backgroundColor('#F3FAFF')
          .border({ width: 1, color: '#CFE3F2' })
          .borderRadius(16)
          .onChange((value: string) => {
            this.editingThought = value;
          })
        Button('保存记录')
          .width('100%')
          .height(50)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFFFF')
          .backgroundColor('#4C90C8')
          .borderRadius(25)
          .onClick(() => {
            this.saveEdit();
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 22, bottom: 34 })
      .backgroundColor('#FBFEFFFF')
      .borderRadius({ topLeft: 28, topRight: 28 })
    }
    .width('100%')
    .height('100%')
  }
}
