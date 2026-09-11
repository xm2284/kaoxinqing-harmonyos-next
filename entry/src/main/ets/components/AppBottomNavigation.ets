import { UiTokens } from '../common/UiTokens';

@Component
export struct AppBottomNavigation {
  @Link currentTab: number;
  onTabSelected: (index: number) => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        this.NavItem(0, '首页', $rawfile('kxq_nav_home_inactive.png'), $rawfile('kxq_nav_home_active.png'))
        this.NavItem(1, '调节', $rawfile('kxq_nav_adjust_inactive.png'), $rawfile('kxq_nav_adjust_active.png'))
        this.NavItem(2, '我的', $rawfile('kxq_nav_my_inactive.png'), $rawfile('kxq_nav_my_active.png'))
      }
      .width('calc(100% - 40vp)')
      .height(UiTokens.NAV_PILL_HEIGHT)
      .padding({ left: 12, right: 12 })
      .backgroundColor(UiTokens.CARD_SOLID)
      .border({ width: 1, color: '#E1E8F2' })
      .borderRadius(22)
      .shadow({ radius: 18, color: '#1A9CB1D5', offsetY: 6 })
    }
    .width('100%')
    .height(UiTokens.NAV_HEIGHT)
    .backgroundColor('#00FFFFFF')
  }

  @Builder
  NavItem(index: number, title: string, icon: Resource, selectedIcon: Resource) {
    Column({ space: 4 }) {
      Image(this.currentTab === index ? selectedIcon : icon)
        .width(this.currentTab === index ? 27 : 24)
        .height(this.currentTab === index ? 27 : 24)
        .objectFit(ImageFit.Contain)
        .scale({
          x: this.currentTab === index ? 1.08 : 1,
          y: this.currentTab === index ? 1.08 : 1
        })
        .animation({ duration: 200, curve: Curve.Friction })
      Text(title)
        .fontSize(12)
        .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTab === index ? UiTokens.PRIMARY : UiTokens.TEXT_SECONDARY)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.onTabSelected(index);
    })
  }
}
