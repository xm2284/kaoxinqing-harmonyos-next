// 考心晴 - 卡片UI页面
// 桌面小组件显示考试倒计时、压力指数、学习进度

const localStorage: LocalStorage = new LocalStorage();

@Entry(localStorage)
@Component
struct WidgetCard {
  @LocalStorageProp('examDays')
  examDays: string = '21';
  @LocalStorageProp('pressureLevel')
  pressureLevel: string = '5';
  @LocalStorageProp('pressureColor')
  pressureColor: string = '#FFD93D';
  @LocalStorageProp('pressureLabel')
  pressureLabel: string = '中低风险';
  @LocalStorageProp('taskProgress')
  taskProgress: string = '0.35';
  @LocalStorageProp('formDimension')
  formDimension: string = '2';
  @LocalStorageProp('title')
  title: string = '考心晴';

  build() {
    Column({ space: 10 }) {
      // 标题行——点击卡片打开应用
      Row() {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.heart'))
            .fontSize(16)
            .fontColor([Color.White])
          Text(this.title)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }

        Blank()

        Text('备考中')
          .fontSize(9)
          .fontColor('#DCE9FF')
          .padding({ left: 7, right: 7, top: 3, bottom: 3 })
          .backgroundColor('#26FFFFFF')
          .borderRadius(10)
      }
      .width('100%')

      // 考试倒计时
      Row() {
        Column({ space: 1 }) {
          Text(`${this.examDays} 天`)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          Text('距离期末考试')
            .fontSize(10)
            .fontColor('#DCE9FF')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 2 }) {
          Row({ space: 5 }) {
            Column()
              .width(8)
              .height(8)
              .borderRadius(4)
              .backgroundColor(this.pressureColor)
            Text(this.pressureLevel)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          Text(this.pressureLabel)
            .fontSize(9)
            .fontColor(Color.White)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(this.pressureColor)
            .borderRadius(9)
        }
      }
      .width('100%')

      if (this.formDimension !== '2') {
        Column({ space: 5 }) {
          Row() {
            Text('今日学习进度')
              .fontSize(10)
              .fontColor('#DCE9FF')
            Blank()
            Text(`${Math.round(parseFloat(this.taskProgress) * 100)}%`)
              .fontSize(10)
              .fontColor(Color.White)
          }
          .width('100%')

          Progress({ value: parseFloat(this.taskProgress), total: 1, type: ProgressType.Linear })
            .width('100%')
            .height(5)
            .color(Color.White)
            .backgroundColor('#3B86FF')
            .borderRadius(3)
        }
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .backgroundColor('#007DFF')
    .borderRadius(22)
    .onClick(() => {
      postCardAction(this, {
        'action': 'router',
        'abilityName': 'EntryAbility',
        'params': {}
      });
    })
  }
}
