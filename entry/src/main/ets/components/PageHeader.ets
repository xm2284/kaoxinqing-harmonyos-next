import { router } from '@kit.ArkUI';
import { UiTokens } from '../common/UiTokens';

@Component
export struct PageHeader {
  title: string = '';
  build() {
    Row({ space: 12 }) {
      Button({ type: ButtonType.Circle }) {
        Image($rawfile('back_arrow.svg')).width(24).height(24)
      }.width(44).height(44).backgroundColor(Color.White).accessibilityText('返回')
        .onClick(() => { router.back(); })
      Text(this.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY).layoutWeight(1)
    }.width('100%').height(64).padding({ left: 16, right: 16, top: 4 })
  }
}
