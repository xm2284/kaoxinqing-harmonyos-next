import { router } from '@kit.ArkUI';
import { AdaptiveLayout } from '../common/AdaptiveLayout';

interface RegulationScene {
  name: string; tag: string; title: string; feeling: string; subtitle: string; time: string; action: string;
  route: string; asset: string; color: string; light: string; surface: string; steps: string[];
}

@Component
export struct AdjustPage {
  @StorageLink('pressureLevel') pressureLevel: number = 3;
  @State contentHeight: number = 680;
  @State contentWidth: number = 390;
  @State active: number = 0;
  private readonly scenes: RegulationScene[] = [
    { name: '云息呼吸', tag: '呼吸放松', title: '让身体先松下来', feeling: '有点紧绷', subtitle: '先放下肩膀，给自己一个\n慢慢呼气的空隙。', time: '3 分钟', action: '跟着呼吸',
      route: 'pages/RelaxationPage', asset: 'kxq_adjust_breath_feature.png', color: '#284F79', light: '#5799B3', surface: '#EDF5FC', steps: ['坐得舒服', '放松肩膀', '跟随节奏'] },
    { name: '松风休息站', tag: '恢复精力', title: '给脑袋放个小假', feeling: '有点疲惫', subtitle: '事情可以稍后再想，\n现在，去树下坐一会儿。', time: '20 分钟', action: '去松风休息',
      route: 'pages/RestBreakPage', asset: 'kxq_adjust_rest_feature.png', color: '#315F54', light: '#81AC84', surface: '#EFF6EB', steps: ['放下任务', '听一段风', '慢慢回来'] },
    { name: '心晴游戏坊', tag: '换个角度', title: '换一扇窗看问题', feeling: '想法打结', subtitle: '不急着否定自己，\n也许还有另一种解释。', time: '随时开始', action: '打开游戏坊',
      route: 'pages/GamePage', asset: 'kxq_adjust_game_feature.png', color: '#67517E', light: '#A88BBE', surface: '#F4EFFA', steps: ['翻一张卡', '看见想法', '换个角度'] },
    { name: '听澜心语', tag: '陪你聊聊', title: '心事可以慢慢说', feeling: '想聊一聊', subtitle: '不必先整理好语言，\n从你想说的那句话开始。', time: '按你的节奏', action: '和听澜聊聊',
      route: 'pages/CognitivePage', asset: 'kxq_ip_sleepy_chat.png', color: '#815D4F', light: '#BE9277', surface: '#FBF2EA', steps: ['说出感受', '有人回应', '找一小步'] }
  ];
  aboutToAppear(): void { this.active = this.pressureLevel >= 6 ? 0 : 1; }
  private open(route: string): void {
    router.pushUrl({ url: route }).catch(() => { this.getUIContext().getPromptAction().showToast({ message: '页面暂时没有打开，请重试。' }); });
  }
  build() {
    Scroll() {
      Column({ space: this.contentHeight < 560 ? 5 : 8 }) {
        Row() {
          Column({ space: 5 }) {
            Text('调节一下').fontSize(25).fontWeight(FontWeight.Bold).fontColor('#253F57')
            Text('找到此刻，适合自己的节奏').fontSize(12).fontColor('#6D8190')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Stack() {
            Circle().width(44).height(44).fill('#E4F0EA')
            Image($rawfile('badge_leaf_color.svg')).width(30).height(30)
          }
        }.width('100%').constraintSize({ minHeight: this.contentHeight < 560 ? 48 : 54 })
        Row({ space: 5 }) {
          ForEach(this.scenes, (scene: RegulationScene, index: number) => {
            Button({ type: ButtonType.Normal }) {
              Text(scene.name).fontSize(this.contentWidth < 360 ? 9 : 10)
                .fontColor(this.active === index ? Color.White : '#586F82').maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Center)
          }.layoutWeight(1).height(this.contentHeight < 560 ? 34 : 38).padding({ left: 2, right: 2 })
              .backgroundColor(this.active === index ? scene.color : '#EAF0F3')
              .fontColor(this.active === index ? Color.White : '#586F82').borderRadius(15).clip(true)
              .onClick(() => { this.active = index; })
          }, (scene: RegulationScene) => scene.route)
        }.width('100%')
        Swiper() {
          ForEach(this.scenes, (scene: RegulationScene, index: number) => {
            this.SceneCard(scene, index)
          }, (scene: RegulationScene) => scene.route)
        }.width('100%').height(this.contentHeight < 560 ? 205 : 244).index(this.active).autoPlay(true).interval(6000).duration(350).loop(true)
          .indicator(false).onChange((index: number) => { this.active = index; })
        Row({ space: 5 }) {
          ForEach(this.scenes, (scene: RegulationScene, index: number) => {
            Column().height(5).width(this.active === index ? 22 : 7).borderRadius(3)
              .backgroundColor(this.active === index ? scene.color : '#D2DDE3')
          })
          Blank().layoutWeight(1)
          Text('左右滑动，换个节奏').fontSize(10).fontColor('#6D8190')
        }.width('100%').height(this.contentHeight < 560 ? 16 : 20)
        Row() {
          Text('留一点时间给自己').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#253F57').layoutWeight(1)
          Text('四种方式').fontSize(11).fontColor('#6D8190')
        }.width('100%').height(this.contentHeight < 560 ? 24 : 28)
        ForEach([0, 1], (row: number) => {
          Row({ space: 10 }) {
            ForEach(this.scenes.slice(row * 2, row * 2 + 2), (scene: RegulationScene) => { this.MethodTile(scene) })
          }.width('100%').height(this.contentHeight < 560 ? 58 : 70)
        })
        Text('不用马上变好，先让这一刻轻一点。').width('100%').textAlign(TextAlign.Center).fontSize(10).fontColor('#758997').height(this.contentHeight < 560 ? 14 : 16)
      }.width('100%').constraintSize({ maxWidth: 680 })
        .padding({ left: AdaptiveLayout.pagePadding(this.contentWidth), right: AdaptiveLayout.pagePadding(this.contentWidth), top: this.contentHeight < 560 ? 5 : 8, bottom: this.contentHeight < 560 ? 5 : 8 })
    }.width('100%').height('100%').scrollBar(BarState.Off)
      .scrollable(ScrollDirection.None)
      .linearGradient({ angle: 160, colors: [['#F4F8F5', 0], ['#EEF4F9', 1]] })
      .onAreaChange((_old: Area, area: Area) => { this.contentHeight = Number(area.height); this.contentWidth = Number(area.width); })
  }
  @Builder SceneCard(scene: RegulationScene, index: number) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Circle().width(180).height(180).fill('#13FFFFFF').margin({ top: -60, right: -44 })
      Circle().width(126).height(126).fill('#12FFFFFF').margin({ top: 30, right: -12 })
      Column({ space: 5 }) {
        Row() {
          Text('0' + (index + 1).toString() + '  /  ' + scene.tag).fontSize(11).fontColor('#DAEDF1').layoutWeight(1)
          Text(scene.time).fontSize(10).fontColor(Color.White).padding({ left: 8, right: 8, top: 4, bottom: 4 }).backgroundColor('#22FFFFFF').borderRadius(10)
        }.width('100%')
        Row({ space: 2 }) {
          Column({ space: this.contentHeight < 560 ? 5 : 7 }) {
            Text(scene.title).fontSize(this.contentWidth < 360 ? 17 : 19).fontWeight(FontWeight.Bold).fontColor(Color.White).maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(scene.subtitle).fontSize(11).lineHeight(17).fontColor('#E2EEF3').maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Button(scene.action).height(this.contentHeight < 560 ? 36 : 40).fontSize(11).fontWeight(FontWeight.Medium).fontColor(scene.color).backgroundColor(Color.White).borderRadius(18)
              .onClick(() => { this.open(scene.route); })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Image($rawfile(scene.asset)).width(this.contentWidth < 360 ? 72 : 88).height(this.contentHeight < 560 ? 78 : 92).objectFit(ImageFit.Contain)
        }.width('100%').layoutWeight(1)
        Row({ space: 6 }) {
          ForEach(scene.steps, (step: string, stepIndex: number) => {
            Text((stepIndex + 1).toString() + ' ' + step).layoutWeight(1).fontSize(9).fontColor('#E4F1F2').textAlign(TextAlign.Center).maxLines(1)
          })
        }.width('100%').height(this.contentHeight < 560 ? 18 : 22).border({ width: { top: 1 }, color: '#30FFFFFF' }).padding({ top: 4 })
      }.width('100%').height('100%').padding(this.contentHeight < 560 ? 12 : 14)
    }.width('100%').height('100%').linearGradient({ angle: 125, colors: [[scene.color, 0], [scene.light, 1]] })
      .borderRadius(26).clip(true)
  }
  @Builder MethodTile(scene: RegulationScene) {
    Column() {
      Row({ space: 5 }) {
        Column({ space: 5 }) {
          Text(scene.name).fontSize(13).fontWeight(FontWeight.Bold).fontColor(scene.color).maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(scene.feeling + ' · ' + scene.time).fontSize(9).fontColor('#687E8B').maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Image($rawfile(scene.asset)).width(this.contentHeight < 560 ? 34 : 40)
          .height(this.contentHeight < 560 ? 34 : 40).objectFit(ImageFit.Contain)
      }.width('100%')
    }.layoutWeight(1).height('100%').justifyContent(FlexAlign.Center)
      .padding({ left: 12, right: 8 }).backgroundColor(scene.surface)
      .border({ width: 1, color: '#DCE7EC' }).borderRadius(22).clip(true)
      .shadow({ radius: 10, color: '#183B5D12', offsetY: 3 })
      .accessibilityText(scene.name + '，' + scene.feeling + '，' + scene.time)
      .onClick(() => { this.open(scene.route); })
  }
}
