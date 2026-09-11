import { router } from '@kit.ArkUI';
import {
  AppConstants,
  AppUsage,
  AssessmentRecord,
  DailyQuote,
  ExamInfo,
  UserProfile
} from '../common/DataModels';
import { MemePopup } from '../common/MemePopup';
import { AdaptiveLayout } from '../common/AdaptiveLayout';
import { UiTokens } from '../common/UiTokens';
import { DatabaseService } from '../services/DatabaseService';
import { HapticService } from '../services/HapticService';
import { MemeService } from '../services/MemeService';

@Component
export struct HomeContent {
  @StorageLink('pressureLevel') pressureLevel: number = 3;
  @StorageLink('targetTab') targetTab: number = 0;
  @StorageLink('expandSection') expandSection: string = '';
  @StorageLink('privacyMode') privacyMode: boolean = false;
  @StorageLink('dataRefreshVersion') @Watch('onDataRefresh') dataRefreshVersion: number = 0;
  @StorageLink('examInfoJson') @Watch('onExamInfoChanged') examInfoJson: string = '';
  @State profile: UserProfile = {
    nickname: '小晴同学',
    grade: '大学二年级',
    school: '我的大学'
  };
  @State exam: ExamInfo = {
    name: '', date: '', subjects: [], createdAt: ''
  };
  @State quote: DailyQuote = {
    content: '不必一下看见终点，先完成眼前这一小步。',
    category: '行动',
    used: false
  };
  @State consecutiveDays: number = 1;
  @State showMeme: boolean = false;
  @State memeAsset: string = 'daily_1';
  @State memeMessage: string = '';
  @State pressedTool: string = '';
  @State pressedAction: string = '';
  @State mascotIndex: number = 0;
  @State mascotEntered: boolean = false;

  @State contentHeight: number = 640;
  @State contentWidth: number = 390;
  private entryTimer: number = -1;

  aboutToDisappear(): void {
    clearTimeout(this.entryTimer);
  }

  aboutToAppear(): void {
    this.refreshHomeMascot();
    this.applyExamSnapshot();
    this.loadOverview();
    this.entryTimer = setTimeout(() => {
      animateTo({ duration: 420, curve: Curve.EaseOut }, () => {
        this.mascotEntered = true;
      });
    }, 80);
  }

  private onDataRefresh(): void {
    this.loadOverview();
  }

  private onExamInfoChanged(): void {
    this.applyExamSnapshot();
  }

  private applyExamSnapshot(): boolean {
    if (this.examInfoJson.trim().length === 0) {
      this.exam = { name: '', date: '', subjects: [], createdAt: '' };
      return false;
    }
    try {
      const snapshot: ExamInfo = JSON.parse(this.examInfoJson) as ExamInfo;
      if (snapshot.name.trim().length === 0 || snapshot.date.trim().length === 0 ||
        snapshot.subjects.length === 0) {
        return false;
      }
      this.exam = {
        id: snapshot.id,
        name: snapshot.name,
        date: snapshot.date,
        subjects: snapshot.subjects.slice(),
        createdAt: snapshot.createdAt
      };
      return true;
    } catch (reason) {
      return false;
    }
  }

  private async loadOverview(): Promise<void> {
    try {
      const hasSnapshot: boolean = this.applyExamSnapshot();
      const profiles: UserProfile[] = await DatabaseService.getAllUserProfiles();
      const exams: ExamInfo[] = await DatabaseService.getAllExamInfo();
      const assessments: AssessmentRecord[] = await DatabaseService.getAllAssessments();
      const quotes: DailyQuote[] = await DatabaseService.getAllDailyQuotes();
      if (profiles.length > 0) {
        this.profile = profiles[0];
        AppStorage.setOrCreate('profileName', profiles[0].nickname);
      }
      if (!hasSnapshot) {
        this.exam = exams.length > 0 ? exams[0] : { name: '', date: '', subjects: [], createdAt: '' };
      }
      if (assessments.length > 0) {
        this.pressureLevel = assessments[0].stressLevel;
      }
      if (quotes.length > 0) {
        const dayIndex: number = Math.floor((Date.now() - new Date().getTimezoneOffset() * 60000) / 86400000) % quotes.length;
        this.quote = quotes[dayIndex];
      }
      await this.recordUsage();
      await this.showDailyMeme();
    } catch (reason) {
      this.getUIContext().getPromptAction().showToast({
        message: '刚才的数据没有加载完整，稍后会再试。',
        duration: 2500
      });
    }
  }

  private async showDailyMeme(): Promise<void> {
    if (await MemeService.shouldShowOnce('daily_open')) {
      this.memeAsset = MemeService.dailyAsset();
      this.memeMessage = this.greeting() + '！今天也要稳稳向前。';
      this.showMeme = true;
    }
  }

  private async recordUsage(): Promise<void> {
    const today: string = this.formatDate(new Date());
    const records: AppUsage[] = await DatabaseService.getAllAppUsage();
    if (records.length > 0 && records[0].date === today) {
      this.consecutiveDays = records[0].consecutiveDays;
      return;
    }
    let streak: number = 1;
    if (records.length > 0) {
      const last: Date = new Date(records[0].date);
      const current: Date = new Date(today);
      const gap: number = Math.round((current.getTime() - last.getTime()) / 86400000);
      if (gap === 1) {
        streak = records[0].consecutiveDays + 1;
      }
    }
    await DatabaseService.addAppUsage({
      date: today,
      consecutiveDays: streak
    });
    this.consecutiveDays = streak;
  }

  private formatDate(date: Date): string {
    const month: string = (date.getMonth() + 1).toString().padStart(2, '0');
    const day: string = date.getDate().toString().padStart(2, '0');
    return date.getFullYear().toString() + '-' + month + '-' + day;
  }

  private greeting(): string {
    const hour: number = new Date().getHours();
    if (hour < 12) {
      return '早上好';
    }
    if (hour < 18) {
      return '下午好';
    }
    return '晚上好';
  }

  private displayName(): string {
    return this.privacyMode ? '同学' : this.profile.nickname;
  }

  private refreshHomeMascot(): void {
    this.mascotIndex = Math.floor(Math.random() * 5);
    this.mascotEntered = false;
  }

  private todayLabel(): string {
    const now: Date = new Date();
    return (now.getMonth() + 1).toString() + '月' + now.getDate().toString() + '日';
  }

  private daysUntilExam(): number {
    return AdaptiveLayout.daysUntil(this.exam.date);
  }

  private openAssessment(): void {
    this.openPage('pages/AssessmentRoutePage');
  }

  private openCoach(): void {
    this.openPage('pages/CognitivePage');
  }

  private openPage(url: string): void {
    HapticService.light();
    router.pushUrl({ url: url }).catch(() => {
      this.getUIContext().getPromptAction().showToast({
        message: '页面暂时没有打开，再试一次？',
        duration: 2500
      });
    });
  }

  private showFullQuote(): void {
    this.getUIContext().getPromptAction().showDialog({
      title: this.quote.category + ' · 每日一谏',
      message: this.quote.content,
      buttons: [
        { text: '知道了', color: AppConstants.COLOR_PRIMARY }
      ]
    });
  }

  private showNotifications(): void {
    const examNotice: string = this.exam.name.length > 0 ?
      '备考提醒：' + this.examLabel() : '还没有设置考试计划，可在首页考试入口中添加。';
    const reminderNotice: string = this.dailyReminderEnabled() ?
      '每日提醒已开启。' : '每日提醒已关闭。';
    this.getUIContext().getPromptAction().showDialog({
      title: '通知',
      message: '暂无新的系统通知。\n\n' + examNotice + '\n' + reminderNotice,
      buttons: [
        { text: '知道了', color: AppConstants.COLOR_PRIMARY }
      ]
    });
  }

  private dailyReminderEnabled(): boolean {
    const value: boolean | undefined = AppStorage.get<boolean>('dailyReminder');
    return value === undefined ? true : value;
  }

  private examLabel(): string {
    if (this.exam.name.length === 0) {
      return '设置考试与计划';
    }
    const days: number = this.daysUntilExam();
    return this.exam.name + ' · ' + (days > 0 ? '还有 ' + days.toString() + ' 天' : '已到考试日期');
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: this.contentHeight < 550 ? 6 : 8 }) {
          this.HomeHeader()
          this.QuoteHero()
          this.AssessmentEntry()
          this.RecommendationCard()
          this.RestStationCard()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .constraintSize({ maxWidth: 680 })
        .height(Math.max(480, this.contentHeight))
        .padding({ left: AdaptiveLayout.pagePadding(this.contentWidth),
          right: AdaptiveLayout.pagePadding(this.contentWidth), top: 6, bottom: 6 })
      }
      .width('100%')
      .height('100%')
      .scrollable(this.contentHeight < 480 ? ScrollDirection.Vertical : ScrollDirection.None)
      .scrollBar(BarState.Off)
      if (this.showMeme) {
        MemePopup({ visible: $showMeme, asset: this.memeAsset, message: this.memeMessage })
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_old: Area, area: Area) => {
      this.contentHeight = Number(area.height);
      this.contentWidth = Number(area.width);
    })
    .linearGradient({ angle: 135,
      colors: [[UiTokens.PAGE_BG_TOP, 0.0], [UiTokens.PAGE_BG_BOTTOM, 1.0]] })
  }

  @Builder
  HomeHeader() {
    Row({ space: 8 }) {
      Column({ space: 0 }) {
        Text(this.greeting() + '，' + this.displayName())
          .fontSize(this.contentWidth < 360 ? 19 : 21)
          .fontWeight(FontWeight.Bold)
          .fontColor(UiTokens.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Button({ type: ButtonType.Normal }) {
          Row({ space: 6 }) {
            Text(this.examLabel())
              .fontSize(13)
              .fontColor(UiTokens.PRIMARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Image($rawfile('kxq_ui_edit_glass.png')).width(16).height(16).objectFit(ImageFit.Contain)
            Text('修改').fontSize(12).fontColor(UiTokens.PRIMARY)
          }
          .width('100%')
        }
        .width('100%')
        .height(44)
        .padding(0)
        .backgroundColor(Color.Transparent)
        .accessibilityText('修改考试与计划，' + this.examLabel())
        .onClick(() => { this.openPage('pages/CountdownSettingPage'); })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button({ type: ButtonType.Circle }) {
        Image($rawfile('home_bell.svg')).width(23).height(23).objectFit(ImageFit.Contain)
      }
      .width(44).height(44)
      .backgroundColor(UiTokens.CARD_SOLID)
      .border({ width: 1, color: UiTokens.CARD_BORDER })
      .accessibilityText('查看通知')
      .onClick(() => { this.showNotifications(); })
    }
    .width('100%').height(this.contentHeight < 550 ? 60 : 66)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  QuoteHero() {
    Row({ space: 4 }) {
      Column({ space: 5 }) {
        Text('每日一谏').fontSize(11).fontColor(UiTokens.PRIMARY).fontWeight(FontWeight.Medium)
        Text(this.quote.content)
          .fontSize(this.contentHeight < 550 ? 15 : (this.contentWidth < 360 ? 16 : 18))
          .fontWeight(FontWeight.Medium)
          .fontColor(UiTokens.TEXT_PRIMARY)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Row({ space: 5 }) {
          Text('小晴陪伴中').fontSize(11).fontColor(UiTokens.TEXT_SECONDARY)
          Column().width(6).height(6).borderRadius(3).backgroundColor('#66C46A')
          Image($rawfile('kxq_home_sprout.png')).width(29).height(24).objectFit(ImageFit.Contain)
        }
        .height(24)
      }
      .height('100%').layoutWeight(1).alignItems(HorizontalAlign.Start)
      this.HomeMascot()
    }
    .width('calc(100% - 8vp)').layoutWeight(1.65)
    .padding({ left: 16, right: 10, top: 12, bottom: 10 })
    .backgroundColor(UiTokens.CARD_SOLID)
    .border({ width: 1, color: UiTokens.CARD_BORDER }).borderRadius(22)
    .accessibilityText('查看每日一谏全文')
    .onClick(() => { this.showFullQuote(); })
  }

  @Builder
  HomeMascot() {
    Image($rawfile(['kxq_ip_sitting.png', 'kxq_ip_reading.png', 'kxq_ip_front.png',
      'kxq_ip_crawl.png', 'kxq_ip_heart_wink.png'][this.mascotIndex]))
      .width(this.contentWidth < 360 ? 68 : 84).height(this.contentHeight < 550 ? 64 : 88)
      .objectFit(ImageFit.Contain)
      .scale({ x: this.mascotEntered ? 1 : 0.9, y: this.mascotEntered ? 1 : 0.9 })
      .opacity(this.mascotEntered ? 1 : 0.72)
  }

  @Builder
  AssessmentEntry() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 10 }) {
        Image($rawfile('kxq_mood_happy.png')).width(32).height(32).objectFit(ImageFit.Contain)
        Column({ space: 3 }) {
          Text('给心情做个小测验').fontSize(15).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
          Text('了解最近的自己，再安排下一步').fontSize(11).fontColor(UiTokens.TEXT_SECONDARY)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text('去测评').fontSize(12).fontWeight(FontWeight.Medium).fontColor(UiTokens.PRIMARY)
      }.width('100%')
    }
    .width('calc(100% - 4vp)').height(this.contentHeight < 550 ? 54 : 60).padding({ left: 12, right: 12 })
    .backgroundColor('#EEF5FF').borderRadius(18)
    .onClick(() => { this.openAssessment(); })
  }

  @Builder
  RecommendationCard() {
    Row({ space: 4 }) {
      Column({ space: 4 }) {
        Text('为你推荐').fontSize(11).fontColor(UiTokens.TEXT_SECONDARY)
        Text('听澜心语').fontSize(this.contentHeight < 550 ? 17 : 19).fontWeight(FontWeight.Bold).fontColor(UiTokens.PRIMARY)
        Text('有些担心，说出来会好一点').fontSize(12).fontColor(UiTokens.TEXT_SECONDARY).maxLines(2)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Image($rawfile('kxq_ip_sleepy_chat.png'))
        .width(this.contentWidth < 360 ? 62 : 78).height(this.contentHeight < 550 ? 60 : 76).objectFit(ImageFit.Contain)
      Button('聊一聊').width(72).height(44).fontSize(12)
        .fontColor(Color.White).backgroundColor(UiTokens.PRIMARY)
        .onClick(() => { this.openCoach(); })
    }
    .width('calc(100% - 16vp)').layoutWeight(this.contentHeight < 550 ? 0 : 1.2).height(this.contentHeight < 550 ? 88 : undefined)
    .padding({ left: 16, right: 12, top: 8, bottom: 8 })
    .linearGradient({ angle: 120, colors: [['#E9F5FF', 0.0], ['#F4FAFF', 1.0]] })
    .border({ width: 1, color: '#DAEAFB' }).borderRadius(22)
    .onClick(() => { this.openCoach(); })
  }

  @Builder
  RestStationCard() {
    Row({ space: 4 }) {
      Column({ space: 6 }) {
        Text('松风休息站').fontSize(18).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
        if (this.contentHeight > 600) {
          Text('给自己 20 分钟真正休息').fontSize(12).fontColor(UiTokens.TEXT_SECONDARY).maxLines(1)
        }
        Button('开始休息').width(100).height(44).fontSize(13).fontWeight(FontWeight.Medium)
          .fontColor(Color.White).backgroundColor(UiTokens.PRIMARY)
          .onClick(() => { this.openPage('pages/RestBreakPage'); })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Image($rawfile('kxq_scene_rest_lake_bench_wide.png'))
        .width(this.contentWidth < 360 ? 130 : 168).height(this.contentHeight < 600 ? 70 : 116).objectFit(ImageFit.Contain)
    }.width('calc(100% - 10vp)').layoutWeight(this.contentHeight < 550 ? 0 : 1.2).height(this.contentHeight < 550 ? 88 : undefined)
      .padding({ left: 18, right: 8, top: 8, bottom: 8 })
      .linearGradient({ angle: 135, colors: [['#F7FFF9', 0.0], ['#EAF7EE', 1.0]] })
      .border({ width: 1, color: '#DDEDDD' }).borderRadius(UiTokens.CARD_RADIUS)
      .onClick(() => { this.openPage('pages/RestBreakPage'); })
  }
}
