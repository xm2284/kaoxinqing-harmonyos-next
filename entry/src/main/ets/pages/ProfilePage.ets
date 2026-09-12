import {
  AppConstants,
  AppUsage,
  AssessmentRecord,
  ChatMessage,
  ThoughtChallenge,
  TrainingRecord,
  UserProfile
} from '../common/DataModels';
import { ApiService } from '../services/ApiService';
import { DatabaseService } from '../services/DatabaseService';
import { MemeService } from '../services/MemeService';
import { SettingsService } from '../services/SettingsService';
import { AssessmentPage } from './AssessmentPage';

@Component
export struct ProfilePage {
  @StorageLink('expandSection') @Watch('onRequestedSection') requestedSection: string = '';
  @StorageLink('dailyReminder') dailyReminder: boolean = true;
  @StorageLink('privacyMode') privacyMode: boolean = false;
  @StorageLink('memeEnabled') memeEnabled: boolean = true;
  @State expandedSection: string = '';
  @State profile: UserProfile = {
    nickname: '小晴同学',
    grade: '大学二年级',
    school: '我的大学'
  };
  @State showProfileSheet: boolean = false;
  @State nicknameDraft: string = '';
  @State gradeDraft: string = '';
  @State schoolDraft: string = '';
  @State apiKeyDraft: string = '';
  @State assessmentCount: number = 0;
  @State averageStress: number = 0;
  @State trainingCount: number = 0;
  @State challengeCount: number = 0;
  @State chatCount: number = 0;
  @State consecutiveDays: number = 1;

  aboutToAppear(): void {
    this.loadProfileData();
    this.onRequestedSection();
  }

  private onRequestedSection(): void {
    if (this.requestedSection.length > 0) {
      this.expandedSection = this.requestedSection;
      AppStorage.setOrCreate('expandSection', '');
    }
  }

  private async loadProfileData(): Promise<void> {
    try {
      const profiles: UserProfile[] = await DatabaseService.getAllUserProfiles();
      const assessments: AssessmentRecord[] = await DatabaseService.getAllAssessments();
      const trainings: TrainingRecord[] = await DatabaseService.getAllTrainingRecords();
      const challenges: ThoughtChallenge[] = await DatabaseService.getAllThoughtChallenges();
      const messages: ChatMessage[] = await DatabaseService.getAllChatMessages();
      const usage: AppUsage[] = await DatabaseService.getAllAppUsage();
      if (profiles.length > 0) {
        this.profile = profiles[0];
      }
      this.assessmentCount = assessments.length;
      this.trainingCount = trainings.length;
      this.challengeCount = challenges.length;
      let userMessages: number = 0;
      for (let index: number = 0; index < messages.length; index++) {
        if (messages[index].role === 'user') {
          userMessages++;
        }
      }
      this.chatCount = userMessages;
      if (usage.length > 0) {
        this.consecutiveDays = usage[0].consecutiveDays;
      }
      if (assessments.length > 0) {
        let sum: number = 0;
        for (let index: number = 0; index < assessments.length; index++) {
          sum += assessments[index].stressLevel;
        }
        this.averageStress = sum / assessments.length;
      }
      this.apiKeyDraft = await ApiService.getApiKey();
      this.memeEnabled = await MemeService.isEnabled();
      AppStorage.setOrCreate('profileName', this.profile.nickname);
      AppStorage.setOrCreate('profileGrade', this.profile.grade);
      AppStorage.setOrCreate('profileSchool', this.profile.school);
    } catch (reason) {
      this.showToast('个人数据暂时没有加载完整。');
    }
  }

  private openProfileEditor(): void {
    this.nicknameDraft = this.profile.nickname;
    this.gradeDraft = this.profile.grade;
    this.schoolDraft = this.profile.school;
    this.showProfileSheet = true;
  }

  private async saveProfile(): Promise<void> {
    if (this.nicknameDraft.trim().length === 0 || this.gradeDraft.trim().length === 0 ||
      this.schoolDraft.trim().length === 0) {
      this.showToast('把昵称、年级和学校补充完整吧。');
      return;
    }
    const updated: UserProfile = {
      nickname: this.nicknameDraft.trim(),
      grade: this.gradeDraft.trim(),
      school: this.schoolDraft.trim()
    };
    try {
      if (this.profile.id !== undefined) {
        updated.id = this.profile.id;
        await DatabaseService.updateUserProfile(updated);
      } else {
        updated.id = await DatabaseService.addUserProfile(updated);
      }
      this.profile = updated;
      AppStorage.setOrCreate('profileName', updated.nickname);
      AppStorage.setOrCreate('profileGrade', updated.grade);
      AppStorage.setOrCreate('profileSchool', updated.school);
      this.showProfileSheet = false;
      this.showToast('个人资料已更新。');
    } catch (reason) {
      this.showToast('资料没有保存成功，再试一次？');
    }
  }

  private async saveSettings(): Promise<void> {
    try {
      await ApiService.saveApiKey(this.apiKeyDraft);
      AppStorage.setOrCreate('apiKey', this.apiKeyDraft.trim());
      await MemeService.setEnabled(this.memeEnabled);
      await SettingsService.save({
        dailyReminder: this.dailyReminder,
        privacyMode: this.privacyMode
      });
      AppStorage.setOrCreate('dailyReminder', this.dailyReminder);
      AppStorage.setOrCreate('privacyMode', this.privacyMode);
      AppStorage.setOrCreate('memeEnabled', this.memeEnabled);
      this.showToast('设置已更新。');
    } catch (reason) {
      this.showToast('设置没有保存成功，再试一次？');
    }
  }

  private toggle(section: string): void {
    this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.expandedSection = this.expandedSection === section ? '' : section;
    });
  }

  private openPage(url: string): void {
    this.getUIContext().getRouter().pushUrl({ url: url }).catch(() => {
      this.showToast('页面暂时没有打开，再试一次？');
    });
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2500 });
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 12 }) {
          Text('我的')
            .width('100%')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppConstants.COLOR_TEXT_PRIMARY)

          Row({ space: 14 }) {
            Stack() {
              Column()
                .width(64)
                .height(64)
                .borderRadius(32)
                .backgroundColor(AppConstants.COLOR_PRIMARY)
              Text(this.privacyMode ? '考' : this.profile.nickname.substring(0, 1))
                .fontSize(26)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppConstants.COLOR_WHITE)
            }
            .width(64)
            .height(64)
            Column({ space: 4 }) {
              Text(this.privacyMode ? '考心晴用户' : this.profile.nickname)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
              Text(this.privacyMode ?
                this.profile.grade + ' · 学校信息已隐藏' :
                this.profile.grade + ' · ' + this.profile.school)
                .fontSize(12)
                .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
                .maxLines(1)
              Text('专注今天，稳步向前')
                .fontSize(11)
                .fontColor(AppConstants.COLOR_PRIMARY)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Button('编辑')
              .height(40)
              .fontSize(13)
              .fontColor(AppConstants.COLOR_PRIMARY)
              .backgroundColor('#14007DFF')
              .onClick(() => {
                this.openProfileEditor();
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#26FFFFFF')
          .backgroundBlurStyle(BlurStyle.Thin)
          .border({ width: 1, color: AppConstants.COLOR_CARD_BORDER })
          .borderRadius(AppConstants.RADIUS_CARD)

          Row({ space: 8 }) {
            this.StatCard(this.consecutiveDays.toString(), '已打卡天数')
            this.StatCard(this.challengeCount.toString(), '挑战想法')
            this.StatCard(this.chatCount.toString(), '教练对话')
          }
          .width('100%')

          Column({ space: 0 }) {
            this.SectionHeader(
              'assessment',
              $r('sys.symbol.eye'),
              '压力测评',
              '了解近两周的焦虑状态'
            )
            if (this.expandedSection === 'assessment') {
              Column() {
                AssessmentPage()
              }
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 16 })
              .transition(TransitionEffect.OPACITY)
            }
          }
          .width('100%')
          .backgroundColor('#26FFFFFF')
          .backgroundBlurStyle(BlurStyle.Thin)
          .border({ width: 1, color: AppConstants.COLOR_CARD_BORDER })
          .borderRadius(AppConstants.RADIUS_CARD)

          Column({ space: 0 }) {
            this.SectionHeader(
              'growth',
              $r('sys.symbol.archivebox'),
              '成长统计',
              '看看你已经积累的改变'
            )
            if (this.expandedSection === 'growth') {
              Row({ space: 8 }) {
                this.SmallStat(this.assessmentCount.toString(), '测评次数')
                this.SmallStat(this.averageStress.toFixed(1), '平均压力')
                this.SmallStat(this.trainingCount.toString(), '放松训练')
              }
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 16 })
            }
          }
          .width('100%')
          .backgroundColor('#26FFFFFF')
          .backgroundBlurStyle(BlurStyle.Thin)
          .border({ width: 1, color: AppConstants.COLOR_CARD_BORDER })
          .borderRadius(AppConstants.RADIUS_CARD)

          Row() {
            this.SectionHeader(
              'analysisRoute',
              $r('sys.symbol.arrow_clockwise'),
              '考后分析',
              '把成绩转化成下一次行动'
            )
          }
          .width('100%')
          .backgroundColor('#26FFFFFF')
          .backgroundBlurStyle(BlurStyle.Thin)
          .border({ width: 1, color: AppConstants.COLOR_CARD_BORDER })
          .borderRadius(AppConstants.RADIUS_CARD)
          .onClick(() => {
            this.openPage('pages/AnalysisPage');
          })

          Column({ space: 0 }) {
            this.SectionHeader(
              'settings',
              $r('sys.symbol.clock'),
              '设置',
              '提醒、隐私与联网服务'
            )
            if (this.expandedSection === 'settings') {
              Column({ space: 14 }) {
                Row() {
                  Text('每日提醒')
                    .fontSize(14)
                    .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
                    .layoutWeight(1)
                  Toggle({ type: ToggleType.Switch, isOn: this.dailyReminder })
                    .selectedColor(AppConstants.COLOR_PRIMARY)
                    .onChange((value: boolean) => {
                      this.dailyReminder = value;
                    })
                }
                .width('100%')
                Row() {
                  Text('隐私模式')
                    .fontSize(14)
                    .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
                    .layoutWeight(1)
                  Toggle({ type: ToggleType.Switch, isOn: this.privacyMode })
                    .selectedColor(AppConstants.COLOR_PRIMARY)
                    .onChange((value: boolean) => {
                      this.privacyMode = value;
                    })
                }
                .width('100%')
                Row() {
                  Text('表情包弹窗')
                    .fontSize(14)
                    .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
                    .layoutWeight(1)
                  Toggle({ type: ToggleType.Switch, isOn: this.memeEnabled })
                    .selectedColor(AppConstants.COLOR_PRIMARY)
                    .onChange((value: boolean) => {
                      this.memeEnabled = value;
                    })
                }
                .width('100%')
                Text('触发时机：首次进入、识别到焦虑主题、翻完六张卡、完成测评或结束休息；同类内容 5 分钟内不重复。')
                  .width('100%')
                  .fontSize(10)
                  .lineHeight(16)
                  .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
                Text('DeepSeek API Key')
                  .width('100%')
                  .fontSize(12)
                  .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
                TextInput({ placeholder: '未填写时使用本地安全演示回复', text: this.apiKeyDraft })
                  .width('100%')
                  .height(46)
                  .type(InputType.Password)
                  .backgroundColor('#99FFFFFF')
                  .borderRadius(12)
                  .onChange((value: string) => {
                    this.apiKeyDraft = value;
                  })
                Text('联网时，同一轮对话会发送至 DeepSeek，由统筹、听澜、明镜、拾光四个 Agent 协作分析。测评、录音和成长记录保存在本地数据库；API Key 不参与分布式同步。')
                  .width('100%')
                  .fontSize(11)
                  .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
                Button('保存设置')
                  .width('100%')
                  .height(44)
                  .fontColor(AppConstants.COLOR_WHITE)
                  .backgroundColor(AppConstants.COLOR_PRIMARY)
                  .onClick(() => {
                    this.saveSettings();
                  })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding({ left: 16, right: 16, bottom: 16 })
            }
          }
          .width('100%')
          .backgroundColor('#26FFFFFF')
          .backgroundBlurStyle(BlurStyle.Thin)
          .border({ width: 1, color: AppConstants.COLOR_CARD_BORDER })
          .borderRadius(AppConstants.RADIUS_CARD)

          Column({ space: 8 }) {
            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
                .fontSize(20)
                .fontColor([AppConstants.COLOR_DANGER])
              Text('心理援助热线')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppConstants.COLOR_DANGER)
            }
            .width('100%')
            Text('北京心理危机研究与干预中心  ' + AppConstants.HOTLINE_BEIJING)
              .width('100%')
              .fontSize(13)
              .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
            Text('全国心理援助热线  ' + AppConstants.HOTLINE_NATIONAL)
              .width('100%')
              .fontSize(13)
              .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
            Text('青少年服务台  ' + AppConstants.HOTLINE_YOUTH)
              .width('100%')
              .fontSize(13)
              .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
            Text('若你或身边的人正处于紧急危险中，请立即联系当地急救或报警服务。')
              .width('100%')
              .fontSize(11)
              .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#0FFF3B30')
          .border({ width: 1, color: '#66FF3B30' })
          .borderRadius(AppConstants.RADIUS_CARD)

          Text('考心晴 · 无忧队')
            .width('100%')
            .padding({ top: 8, bottom: 24 })
            .textAlign(TextAlign.Center)
            .fontSize(11)
            .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
        }
        .width('100%')
        .padding({
          left: AppConstants.PADDING_PAGE,
          right: AppConstants.PADDING_PAGE,
          top: 16,
          bottom: 16
        })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppConstants.COLOR_BACKGROUND)
    .bindSheet($$this.showProfileSheet, this.ProfileSheet(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      backgroundColor: '#F7FFFFFF'
    })
  }

  @Builder
  StatCard(value: string, label: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppConstants.COLOR_PRIMARY)
      Text(label)
        .fontSize(11)
        .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
    }
    .layoutWeight(1)
    .height(78)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#26FFFFFF')
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: AppConstants.COLOR_CARD_BORDER })
    .borderRadius(16)
  }

  @Builder
  SmallStat(value: string, label: string) {
    Column({ space: 3 }) {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppConstants.COLOR_PRIMARY)
      Text(label)
        .fontSize(10)
        .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
    }
    .layoutWeight(1)
    .height(64)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#66FFFFFF')
    .borderRadius(12)
  }

  @Builder
  SectionHeader(section: string, icon: Resource, title: string, description: string) {
    Row({ space: 12 }) {
      Stack() {
        Column()
          .width(42)
          .height(42)
          .borderRadius(21)
          .backgroundColor('#14007DFF')
        SymbolGlyph(icon)
          .fontSize(21)
          .fontColor([AppConstants.COLOR_PRIMARY])
      }
      .width(42)
      .height(42)
      Column({ space: 3 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
        Text(description)
          .fontSize(11)
          .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(section === 'analysisRoute' ? '进入' :
        this.expandedSection === section ? '收起' : '展开')
        .fontSize(11)
        .fontColor(AppConstants.COLOR_PRIMARY)
        .padding({ left: 9, right: 9, top: 5, bottom: 5 })
        .backgroundColor('#12007DFF')
        .borderRadius(10)
    }
    .width('100%')
    .height(72)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      if (section !== 'analysisRoute') {
        this.toggle(section);
      }
    })
  }

  @Builder
  ProfileSheet() {
    Column({ space: 14 }) {
      Text('编辑个人资料')
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
      TextInput({ placeholder: '昵称', text: this.nicknameDraft })
        .width('100%')
        .height(46)
        .backgroundColor('#99F0F5FF')
        .borderRadius(12)
        .onChange((value: string) => {
          this.nicknameDraft = value;
        })
      TextInput({ placeholder: '年级，例如：大学二年级', text: this.gradeDraft })
        .width('100%')
        .height(46)
        .backgroundColor('#99F0F5FF')
        .borderRadius(12)
        .onChange((value: string) => {
          this.gradeDraft = value;
        })
      TextInput({ placeholder: '学校', text: this.schoolDraft })
        .width('100%')
        .height(46)
        .backgroundColor('#99F0F5FF')
        .borderRadius(12)
        .onChange((value: string) => {
          this.schoolDraft = value;
        })
      Button('保存资料')
        .width('100%')
        .height(48)
        .fontColor(AppConstants.COLOR_WHITE)
        .backgroundColor(AppConstants.COLOR_PRIMARY)
        .onClick(() => {
          this.saveProfile();
        })
    }
    .width('100%')
    .padding(20)
  }
}
