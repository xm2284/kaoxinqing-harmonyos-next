import { AppConstants } from './DataModels';

@Component
export struct MemePopup {
  @Link visible: boolean;
  @Prop asset: string = 'daily_1';
  @Prop message: string = '';
  @Prop featured: boolean = false;
  @Prop displayDuration: number = 3000;
  private timerId: number = -1;

  aboutToAppear(): void {
    if (this.displayDuration > 0) {
      this.timerId = setTimeout(() => {
        this.visible = false;
      }, this.displayDuration);
    }
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#26000000')
      Column({ space: 10 }) {
        this.PopupImage()
        Text(this.message)
          .fontSize(this.featured ? 15 : 14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
          .textAlign(TextAlign.Center)
          .maxLines(this.featured ? 3 : 2)
        if (this.featured) {
          Text('轻触任意位置继续')
            .fontSize(11)
            .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
        }
      }
      .width(this.featured ? 286 : 220)
      .padding(this.featured ? 18 : 16)
      .backgroundColor('#E8FFFFFF')
      .backgroundBlurStyle(BlurStyle.Thick)
      .border({ width: 1, color: AppConstants.COLOR_CARD_BORDER })
      .borderRadius(20)
      .shadow({ radius: 12, color: '#18000000', offsetY: 4 })
      .transition(
        TransitionEffect.scale({ x: 0.8, y: 0.8 })
          .combine(TransitionEffect.OPACITY)
          .animation({ duration: 200, curve: Curve.Friction })
      )
    }
    .width('100%')
    .height('100%')
    .zIndex(100)
    .onClick(() => {
      this.visible = false;
    })
  }

  @Builder
  PopupImage() {
    if (this.asset === 'breakdown') {
      Image($rawfile('meme_breakdown.png'))
        .width(this.featured ? 196 : 132)
        .height(this.featured ? 196 : 132)
        .objectFit(ImageFit.Cover)
        .borderRadius(18)
    } else if (this.asset === 'songhao') {
      Image($rawfile('meme_songhao.png'))
        .width(this.featured ? 196 : 132)
        .height(this.featured ? 196 : 132)
        .objectFit(ImageFit.Cover)
        .borderRadius(18)
    } else if (this.asset === 'studycat') {
      Image($rawfile('meme_studycat.png'))
        .width(this.featured ? 196 : 132)
        .height(this.featured ? 196 : 132)
        .objectFit(ImageFit.Cover)
        .borderRadius(18)
    } else if (this.asset === 'daily_2') {
      Image($rawfile('meme_daily_2.png'))
        .width(this.featured ? 196 : 132)
        .height(this.featured ? 196 : 132)
        .objectFit(ImageFit.Cover)
        .borderRadius(18)
    } else if (this.asset === 'daily_3') {
      Image($rawfile('meme_daily_3.png'))
        .width(this.featured ? 196 : 132)
        .height(this.featured ? 196 : 132)
        .objectFit(ImageFit.Cover)
        .borderRadius(18)
    } else if (this.asset === 'daily_4') {
      Image($rawfile('meme_daily_4.png'))
        .width(this.featured ? 196 : 132)
        .height(this.featured ? 196 : 132)
        .objectFit(ImageFit.Cover)
        .borderRadius(18)
    } else if (this.asset === 'daily_5') {
      Image($rawfile('meme_daily_5.png'))
        .width(this.featured ? 196 : 132)
        .height(this.featured ? 196 : 132)
        .objectFit(ImageFit.Cover)
        .borderRadius(18)
    } else if (this.asset === 'go_study') {
      Image($rawfile('go_study_reminder.png'))
        .width(this.featured ? 196 : 132)
        .height(this.featured ? 196 : 132)
        .objectFit(ImageFit.Cover)
        .borderRadius(18)
    } else {
      Image($rawfile('meme_daily_1.png'))
        .width(this.featured ? 196 : 132)
        .height(this.featured ? 196 : 132)
        .objectFit(ImageFit.Cover)
        .borderRadius(18)
    }
  }
}
