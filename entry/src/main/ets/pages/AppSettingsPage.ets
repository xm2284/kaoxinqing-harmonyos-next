import { UserProfile } from '../common/DataModels';
import { UiTokens } from '../common/UiTokens';
import { PageHeader } from '../components/PageHeader';
import { DatabaseService } from '../services/DatabaseService';
import { ApiService } from '../services/ApiService';
import { SettingsService } from '../services/SettingsService';
import { MemeService } from '../services/MemeService';

@Entry
@Component
struct AppSettingsPage {
  @State nickname: string = '';
  @State grade: string = '';
  @State school: string = '';
  @State apiKey: string = '';
  @State keyConfigured: boolean = false;
  @State privacy: boolean = false;
  @State meme: boolean = true;
  @State loading: boolean = true;
  @State failed: boolean = false;
  @State saving: boolean = false;
  private profileId: number = -1;
  private dailyReminder: boolean = true;

  aboutToAppear(): void { this.load(); }
  private toast(text: string): void { this.getUIContext().getPromptAction().showToast({ message: text }); }
  private async load(): Promise<void> {
    this.loading = true; this.failed = false;
    try {
      const profiles: UserProfile[] = await DatabaseService.getAllUserProfiles();
      if (profiles.length > 0) {
        this.profileId = profiles[0].id ?? -1; this.nickname = profiles[0].nickname;
        this.grade = profiles[0].grade; this.school = profiles[0].school;
      }
      const settings = await SettingsService.load();
      this.privacy = settings.privacyMode; this.dailyReminder = settings.dailyReminder;
      this.meme = await MemeService.isEnabled();
      this.keyConfigured = (await ApiService.getApiKey()).length > 0;
    } catch (reason) { this.failed = true; this.toast('设置未加载完整，请重新加载。'); }
    finally { this.loading = false; }
  }
  private async save(): Promise<void> {
    if (this.saving || this.loading || this.failed) { return; }
    if (this.nickname.trim().length === 0) { this.toast('给自己起个昵称吧。'); return; }
    if (this.apiKey.trim().length > 0 && /\s/.test(this.apiKey.trim())) {
      this.toast('API Key 中不能包含空格或换行。'); return;
    }
    this.saving = true;
    try {
      const profile: UserProfile = { nickname: this.nickname.trim(), grade: this.grade.trim(), school: this.school.trim() };
      if (this.profileId > 0) { profile.id = this.profileId; await DatabaseService.updateUserProfile(profile); }
      else { this.profileId = await DatabaseService.addUserProfile(profile); }
      AppStorage.setOrCreate('profileName', profile.nickname);
      AppStorage.setOrCreate('profileGrade', profile.grade);
      AppStorage.setOrCreate('profileSchool', profile.school);
      DatabaseService.notifyChanged();
      await SettingsService.save({ dailyReminder: this.dailyReminder, privacyMode: this.privacy });
      await MemeService.setEnabled(this.meme);
      AppStorage.setOrCreate('privacyMode', this.privacy);
      if (this.apiKey.trim().length > 0) {
        await ApiService.saveApiKey(this.apiKey.trim()); this.keyConfigured = true; this.apiKey = '';
      }
      this.toast('已保存，首页与个人资料已同步。');
    } catch (reason) { this.toast('部分设置未保存成功，请保留输入后重试。'); }
    finally { this.saving = false; }
  }
  private clearKey(): void {
    this.getUIContext().getPromptAction().showDialog({ title: '移除 API Key？',
      message: '移除后将恢复本地陪伴，已有聊天记录保留。',
      buttons: [{ text: '取消', color: UiTokens.TEXT_SECONDARY }, { text: '移除', color: '#C84E48' }]
    }).then(async (result) => {
      if (result.index !== 1) { return; }
      this.saving = true;
      try { await ApiService.saveApiKey(''); this.apiKey = ''; this.keyConfigured = false; this.toast('已恢复本地陪伴。'); }
      catch (reason) { this.toast('没有移除成功，请重试。'); }
      finally { this.saving = false; }
    });
  }
  build() {
    Column() {
      PageHeader({ title: '设置与个人资料' })
      if (this.failed) { Button('加载失败，重新加载').height(44).onClick(() => { this.load(); }) }
      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 10 }) {
            this.Title('个人资料', '昵称会显示在首页问候中')
            TextInput({ placeholder: '昵称', text: this.nickname }).maxLength(16).height(46).fontSize(14)
              .onChange((value: string) => { this.nickname = value; })
            TextInput({ placeholder: '年级（选填）', text: this.grade }).maxLength(24).height(46).fontSize(14)
              .onChange((value: string) => { this.grade = value; })
            TextInput({ placeholder: '学校（选填）', text: this.school }).maxLength(40).height(46).fontSize(14)
              .onChange((value: string) => { this.school = value; })
          }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(22)
          Column({ space: 12 }) {
            this.Title('听澜心语 · 模型连接', this.keyConfigured ? '已配置 Key · 可使用在线模型' : '本地陪伴模式 · 不需要 Key')
            Text('支持 DeepSeek API。保存后，普通聊天会通过 HTTPS 发送到 DeepSeek；本地识别到的高风险表达会先进入求助流程。')
              .fontSize(12).fontColor(UiTokens.TEXT_SECONDARY).width('100%')
            TextInput({ placeholder: this.keyConfigured ? '填写新 Key 可替换；留空则保留' : '粘贴你的 DeepSeek API Key', text: this.apiKey })
              .type(InputType.Password).height(48).fontSize(13).maxLength(512)
              .onChange((value: string) => { this.apiKey = value; })
            Text('Key 仅保存在本机应用设置中，不显示在首页或日志中。保存配置不会立即发起聊天请求。')
              .fontSize(11).fontColor(UiTokens.TEXT_SECONDARY).width('100%')
            if (this.keyConfigured) {
              Button('移除 Key，使用本地陪伴').height(44).fontSize(13).backgroundColor('#FFF2F0').fontColor('#BA4D48')
                .onClick(() => { this.clearKey(); })
            }
          }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(22)
          Column({ space: 8 }) {
            Row() {
              Column({ space: 4 }) {
                Text('隐私显示').fontSize(15).fontWeight(FontWeight.Bold)
                Text('隐藏首页昵称和个人页学校').fontSize(11).fontColor(UiTokens.TEXT_SECONDARY)
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Toggle({ type: ToggleType.Switch, isOn: this.privacy }).onChange((value: boolean) => { this.privacy = value; })
            }.width('100%')
            Row() {
              Column({ space: 4 }) {
                Text('趣味陪伴弹窗').fontSize(15).fontWeight(FontWeight.Bold)
                Text('关闭日常趣味弹窗，保留求助提示').fontSize(11).fontColor(UiTokens.TEXT_SECONDARY)
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Toggle({ type: ToggleType.Switch, isOn: this.meme }).onChange((value: boolean) => { this.meme = value; })
            }.width('100%')
          }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(22)
          Button(this.saving ? '正在保存…' : '保存设置').width('100%').height(48).fontSize(15)
            .backgroundColor(UiTokens.PRIMARY).onClick(() => { this.save(); })
        }.width('100%').constraintSize({ maxWidth: 680 }).padding({ left: 16, right: 16, bottom: 24 })
          .enabled(!this.loading && !this.saving && !this.failed)
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor(UiTokens.PAGE_BG_TOP)
  }
  @Builder Title(title: string, note: string) {
    Column({ space: 4 }) {
      Text(title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
      Text(note).fontSize(11).fontColor(UiTokens.TEXT_SECONDARY)
    }.alignItems(HorizontalAlign.Start).width('100%')
  }
}
