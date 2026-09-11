import { call } from '@kit.TelephonyKit';
import { UiTokens } from '../common/UiTokens';
import { PageHeader } from '../components/PageHeader';

@Entry
@Component
struct SupportPage {
  private dial(number: string): void {
    call.makeCall(number).catch(() => {
      this.getUIContext().getPromptAction().showToast({ message: '未能打开拨号界面，请手动拨打 ' + number });
    });
  }
  build() {
    Column() {
      PageHeader({ title: '心理支持与求助' })
      Scroll() {
        Column({ space: 16 }) {
          Text('难熬的时候，\n让一个真实的人陪你。').fontSize(23).fontWeight(FontWeight.Medium)
            .fontColor(UiTokens.TEXT_PRIMARY).width('100%')
          Text('如果你已经受伤、服药过量，或可能马上伤害自己，请优先联系紧急服务或就近急诊。')
            .fontSize(14).fontColor('#9D4A43').padding(16).backgroundColor('#FFF0EA').borderRadius(18)
          this.Hotline('12356', '全国统一心理援助热线', '适用于中国大陆，提供心理支持与求助指引。服务时段以当地接听机构为准。', '#EAF4FF')
          this.Hotline('120', '医疗急救', '已经受伤、服药过量或身体情况危急时，请及时寻求急救。', '#FFF1E9')
          this.Hotline('110', '紧急求助', '处于迫近的人身危险，或需要警方紧急协助时使用。', '#F0F3FF')
          Column({ space: 10 }) {
            Text('现在可以先做的事').fontSize(17).fontWeight(FontWeight.Bold)
            Text('1. 离开危险的地点，让可能伤害自己的物品远离身边。\n2. 到有人陪伴的安全地方，联系信任的家人、朋友或老师。\n3. 可以直接说：“我现在很难受，需要你陪我一下。”')
              .fontSize(14).lineHeight(23).fontColor(UiTokens.TEXT_SECONDARY)
            Text('在中国大陆以外，请联系所在地的紧急服务或危机支持机构。应用不能代替急救或专业诊疗。')
              .fontSize(12).fontColor(UiTokens.TEXT_SECONDARY)
          }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(Color.White).borderRadius(20)
          Text('点击号码只会打开系统拨号页，由你确认拨出。12356 信息依据国家卫生健康委公开通知。')
            .fontSize(11).fontColor(UiTokens.TEXT_SECONDARY)
        }.width('100%').constraintSize({ maxWidth: 680 }).padding({ left: 20, right: 20, top: 12, bottom: 24 })
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor(UiTokens.PAGE_BG_TOP)
  }
  @Builder Hotline(number: string, title: string, detail: string, color: string) {
    Column({ space: 8 }) {
      Row() {
        Text(number).fontSize(29).fontWeight(FontWeight.Bold).fontColor(UiTokens.PRIMARY).layoutWeight(1)
        Button('打开拨号').height(44).fontSize(13).backgroundColor(UiTokens.PRIMARY).onClick(() => { this.dial(number); })
      }.width('100%')
      Text(title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
      Text(detail).fontSize(12).fontColor(UiTokens.TEXT_SECONDARY)
    }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor(color).borderRadius(20)
  }
}
