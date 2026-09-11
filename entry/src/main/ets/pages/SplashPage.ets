import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppConstants } from '../common/DataModels';

@Entry
@Component
struct SplashPage {
  @State titleOpacity: number = 0;
  @State titleScale: number = 0.8;
  @State sloganOpacity: number = 0;
  @State progress: number = 0;
  private routeTimer: number = -1;
  private animationTimer: number = -1;

  aboutToAppear(): void {
    this.setFullScreen(true);
    this.animationTimer = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 1000, curve: Curve.EaseOut }, () => {
        this.titleOpacity = 1;
        this.titleScale = 1;
      });
      this.getUIContext().animateTo({ duration: 700, delay: 500, curve: Curve.EaseOut }, () => {
        this.sloganOpacity = 1;
      });
      this.getUIContext().animateTo({ duration: 2450, curve: Curve.Linear }, () => {
        this.progress = 100;
      });
    }, 50);

    this.routeTimer = setTimeout(() => {
      this.setFullScreen(false);
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' }).catch(() => {
        console.error('Splash route failed');
      });
    }, 2500);
  }

  aboutToDisappear(): void {
    this.clearTimers();
    this.setFullScreen(false);
  }

  private clearTimers(): void {
    if (this.routeTimer !== -1) {
      clearTimeout(this.routeTimer);
      this.routeTimer = -1;
    }
    if (this.animationTimer !== -1) {
      clearTimeout(this.animationTimer);
      this.animationTimer = -1;
    }
  }

  private setFullScreen(enabled: boolean): void {
    const context: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext;
    window.getLastWindow(context).then((appWindow: window.Window) => {
      appWindow.setWindowLayoutFullScreen(enabled).catch(() => {
        console.error('Set splash fullscreen failed');
      });
    }).catch(() => {
      console.error('Get splash window failed');
    });
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Image($r('app.media.splashBg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#1AFFFFFF')

      Column({ space: 10 }) {
        Image($r('app.media.app_icon'))
          .width(76)
          .height(76)
          .borderRadius(20)
        Text(AppConstants.APP_NAME)
          .fontSize(38)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
          .letterSpacing(3)
          .opacity(this.titleOpacity)
          .scale({ x: this.titleScale, y: this.titleScale })
        Text(AppConstants.SLOGAN)
          .fontSize(15)
          .fontColor('#66645F')
          .opacity(this.sloganOpacity)
      }
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 26, right: 26, top: 22, bottom: 22 })
      .backgroundColor('#B8FFFDF8')
      .borderRadius(26)
      .shadow({ radius: 12, color: '#1A000000', offsetY: 5 })
      .translate({ y: -180 })

      Column({ space: 12 }) {
        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width(220)
            .height(4)
            .borderRadius(2)
            .backgroundColor('#66FFFFFF')
          Row()
            .width(this.progress * 2.2)
            .height(4)
            .borderRadius(2)
            .backgroundColor(AppConstants.COLOR_PRIMARY)
        }
        .width(220)
        .height(4)

        Text('正在准备你的晴朗空间')
          .fontSize(12)
          .fontColor('#665D52')
      }
      .alignItems(HorizontalAlign.Center)
      .align(Alignment.Bottom)
      .margin({ bottom: 54 })
    }
    .width('100%')
    .height('100%')
  }
}
