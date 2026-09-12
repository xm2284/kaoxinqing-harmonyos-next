import { AppConstants } from '../common/DataModels';
import { UiTokens } from '../common/UiTokens';
import { AppBottomNavigation } from '../components/AppBottomNavigation';
import { DatabaseService } from '../services/DatabaseService';
import { AdjustPage } from './AdjustPage';
import { HomeContent } from './HomeContent';
import { MyPage } from './MyPage';

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @StorageLink('targetTab') @Watch('onTargetTabChanged') targetTab: number = 0;
  @StorageLink('pendingRoute') @Watch('onPendingRouteChanged') pendingRoute: string = '';
  @StorageLink('hasContinuation') hasContinuation: boolean = false;

  onPageShow(): void {
    DatabaseService.notifyChanged();
  }

  aboutToAppear(): void {
    this.changeTab(this.targetTab);
    this.openPendingRoute();
    this.showContinuationIfNeeded();
  }

  private showContinuationIfNeeded(): void {
    if (!this.hasContinuation) {
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: '继续上次的压力测评？',
      message: '上次的答案已经安全保留，可以从中断的位置继续。',
      buttons: [
        { text: '继续测评', color: AppConstants.COLOR_PRIMARY },
        { text: '稍后', color: AppConstants.COLOR_TEXT_SECONDARY }
      ]
    }).then((result) => {
      AppStorage.setOrCreate('hasContinuation', false);
      if (result.index === 0) {
        AppStorage.setOrCreate('pendingRoute', 'pages/AssessmentRoutePage');
      }
    });
  }

  private onTargetTabChanged(): void {
    this.changeTab(this.targetTab);
  }

  private changeTab(index: number): void {
    if (index < 0 || index > 2) {
      return;
    }
    this.currentTab = index;
  }

  private onPendingRouteChanged(): void {
    this.openPendingRoute();
  }

  private openPendingRoute(): void {
    if (this.pendingRoute.length === 0) {
      return;
    }
    const route: string = this.pendingRoute;
    AppStorage.setOrCreate('pendingRoute', '');
    this.getUIContext().getRouter().pushUrl({ url: route }).catch(() => {
      this.getUIContext().getPromptAction().showToast({
        message: '页面暂时没有打开，再试一次？',
        duration: 2500
      });
    });
  }

  build() {
    Column() {
      Stack() {
        if (this.currentTab === 0) {
          HomeContent()
        } else if (this.currentTab === 1) {
          AdjustPage()
        } else {
          MyPage()
        }
      }
      .layoutWeight(1)
      .width('100%')

      AppBottomNavigation({
        currentTab: $currentTab,
        onTabSelected: (index: number) => {
          this.changeTab(index);
          AppStorage.setOrCreate('targetTab', index);
        }
      })
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 135,
      colors: [[UiTokens.PAGE_BG_TOP, 0.0], [UiTokens.PAGE_BG_BOTTOM, 1.0]]
    })
  }
}
