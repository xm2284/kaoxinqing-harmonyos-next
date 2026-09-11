import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { AppConstants, UserProfile, VideoShare } from '../common/DataModels';
import { MemePopup } from '../common/MemePopup';
import { LiveViewService } from '../service/LiveViewService';
import { DatabaseService } from '../services/DatabaseService';
import { HapticService } from '../services/HapticService';
import { AmbientAudioService } from '../services/AmbientAudioService';
import { BilibiliService } from '../services/BilibiliService';
import { MemeService } from '../services/MemeService';

@Entry
@Component
struct RestBreakPage {
  @State viewportHeight: number = 760;
  @State viewportWidth: number = 390;
  @State videos: VideoShare[] = [];
  @State profile: UserProfile = {
    nickname: '小晴同学',
    grade: '大学二年级',
    school: '我的大学'
  };
  @State likedIds: number[] = [];
  @State showShareSheet: boolean = false;
  @State shareLink: string = '';
  @State shareTitle: string = '';
  @State shareReason: string = '';
  @State shareCategory: string = '治愈系';
  @State editingShareId: number = -1;
  @State resting: boolean = false;
  @State remainingSeconds: number = 1200;
  @State showMeme: boolean = false;
  @State showIntro: boolean = false;
  @State pageMode: number = 0;
  @State treeHoleTab: number = 0;
  @State soundPlaying: boolean = false;
  @State soundLoading: boolean = false;
  @State showSoundPicker: boolean = false;
  @State selectedSound: string = 'ocean';
  @State soundVolume: number = 45;
  @State savingShare: boolean = false;
  private ambient: AmbientAudioService = new AmbientAudioService();
  private restStartedAt: number = 0;
  private timerId: number = -1;
  private liveView: LiveViewService =
    new LiveViewService('休息计时', 'kaoxinqing_rest', 20260727);

  aboutToAppear(): void {
    this.ambient.onPlaybackChanged = (playing: boolean) => { this.soundPlaying = playing; };
    this.loadData();
    this.checkFirstVisit();
  }

  aboutToDisappear(): void {
    this.ambient.stop().catch(() => {});
    this.clearTimer();
    this.liveView.stop(false, '休息计时已结束');
  }

  onPageHide(): void { this.ambient.stop().catch(() => {}); }

  private soundName(): string {
    return this.selectedSound === 'ocean' ? '海浪白噪音' : (this.selectedSound === 'rain' ? '窗边雨声' : '林间风声');
  }

  private async playSound(key: string): Promise<void> {
    if (this.soundLoading) { return; }
    if (this.selectedSound === key && this.soundPlaying) { await this.ambient.stop().catch(() => {}); return; }
    this.selectedSound = key; this.soundLoading = true;
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      await this.ambient.play(context, 'ambient_' + key + '.wav');
    } catch (reason) { this.soundPlaying = false; this.showToast('声音暂时无法播放，请重试。'); }
    finally { this.soundLoading = false; }
  }

  onBackPress(): boolean {
    this.confirmExit();
    return true;
  }

  private confirmExit(): void {
    if (this.pageMode === 1 && !this.resting) { this.pageMode = 0; return; }
    if (!this.resting) {
      router.back();
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: '休息计时还在进行',
      message: '现在离开会结束本次休息计时，确定离开吗？',
      buttons: [
        { text: '继续休息', color: AppConstants.COLOR_PRIMARY },
        { text: '结束并离开', color: AppConstants.COLOR_DANGER }
      ]
    }).then((result) => {
      if (result.index === 1) {
        this.finishRest(false).then(() => {
          router.back();
        });
      }
    });
  }

  private async loadData(): Promise<void> {
    try {
      await DatabaseService.ensurePresetVideos();
      const storedVideos: VideoShare[] = await DatabaseService.getAllVideoShares();
      this.videos = storedVideos;
      if (this.videos.length === 0) {
        this.videos = this.fallbackVideos();
      }
      const profiles: UserProfile[] = await DatabaseService.getAllUserProfiles();
      if (profiles.length > 0) {
        this.profile = profiles[0];
      }
      this.videos = this.videos.filter((item: VideoShare) => AppConstants.PRESET_VIDEOS.some((preset: VideoShare) => preset.bvid === item.bvid) || item.sharer === this.profile.nickname)
        .map((item: VideoShare) => {
          const preset: VideoShare | undefined = AppConstants.PRESET_VIDEOS.find((entry: VideoShare) => entry.bvid === item.bvid);
          if (preset !== undefined) {
            return { id: item.id, bvid: preset.bvid, title: preset.title, coverUrl: preset.coverUrl,
              shareReason: preset.shareReason, sharer: preset.sharer, category: preset.category,
              likes: item.likes, createdAt: preset.createdAt, duration: preset.duration, views: preset.views, author: preset.author } as VideoShare;
          }
          return item;
        });
    } catch (reason) {
      this.videos = this.fallbackVideos();
      this.showToast('树洞内容暂时没有加载出来。');
    }
  }

  private async checkFirstVisit(): Promise<void> {
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const store: preferences.Preferences =
        await preferences.getPreferences(context, 'kaoxinqing_onboarding');
      const seenValue: preferences.ValueType = await store.get('rest_break_intro_v2', false);
      if (!(seenValue as boolean)) {
        this.showIntro = true;
        await store.put('rest_break_intro_v2', true);
        await store.flush();
      }
    } catch (reason) {
      this.showIntro = true;
    }
  }

  private fallbackVideos(): VideoShare[] {
    const result: VideoShare[] = [];
    for (let index: number = 0; index < AppConstants.PRESET_VIDEOS.length; index++) {
      const source: VideoShare = AppConstants.PRESET_VIDEOS[index];
      result.push({
        id: -(index + 1),
        bvid: source.bvid,
        coverUrl: source.coverUrl,
        title: source.title,
        shareReason: source.shareReason,
        sharer: source.sharer,
        likes: source.likes,
        category: source.category,
        createdAt: source.createdAt
      });
    }
    return result;
  }

  private isLiked(id: number): boolean {
    return this.likedIds.indexOf(id) >= 0;
  }

  private async toggleLike(item: VideoShare): Promise<void> {
    if (item.id === undefined) {
      return;
    }
    HapticService.light();
    const ids: number[] = this.likedIds.slice();
    const position: number = ids.indexOf(item.id);
    if (position >= 0) {
      ids.splice(position, 1);
      item.likes = Math.max(0, item.likes - 1);
      this.showToast('已取消');
    } else {
      ids.push(item.id);
      item.likes++;
      this.showToast('已点赞');
    }
    this.likedIds = ids;
    if (item.id < 0) {
      this.videos = this.videos.slice();
      return;
    }
    try {
      await DatabaseService.updateVideoShare(item);
      await this.loadData();
    } catch (reason) {
      this.showToast('刚才没有同步成功，再试一次？');
    }
  }

  private async openVideo(item: VideoShare): Promise<void> {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      await context.openLink('https://www.bilibili.com/video/' + item.bvid);
    } catch (reason) {
      this.showToast('没有找到可打开这个视频的应用。');
    }
  }

  private extractBvid(link: string): string {
    const index: number = link.indexOf('BV');
    if (index < 0 || link.length < index + 12) {
      return '';
    }
    return link.substring(index, index + 12);
  }

  private async saveShare(): Promise<void> {
    if (this.savingShare) { return; }
    const bvid: string = this.extractBvid(this.shareLink.trim());
    if (bvid.length === 0 || this.shareReason.trim().length === 0) {
      this.showToast('请填写有效的B站链接和推荐理由，标题与封面会自动读取。');
      return;
    }
    this.savingShare = true;
    let item: VideoShare;
    try {
      item = await BilibiliService.resolve(bvid);
      item.shareReason = this.shareReason.trim(); item.sharer = this.profile.nickname; item.category = this.shareCategory;
    } catch (reason) {
      this.savingShare = false; this.showToast('暂时无法核实该视频，链接和输入已保留，请稍后重试。'); return;
    }
    if (this.editingShareId > 0) {
      for (let index: number = 0; index < this.videos.length; index++) {
        const current: VideoShare = this.videos[index];
        if (current.id === this.editingShareId) {
          item.id = current.id;

          item.likes = current.likes;
          item.createdAt = current.createdAt;
          break;
        }
      }
    }
    try {
      const wasEditing: boolean = this.editingShareId > 0;
      if (this.editingShareId > 0) {
        await DatabaseService.updateVideoShare(item);
      } else {
        await DatabaseService.addVideoShare(item);
      }
      this.showShareSheet = false;
      this.clearShareDraft();
      await this.loadData();
      this.showToast(wasEditing ? '本机推荐已更新。' : '已收录到本机树洞。');
    } catch (reason) {
      this.showToast('这次没有保存成功，内容已经为你保留。');
    } finally { this.savingShare = false; }
  }

  private cancelShare(): void {
    if (this.savingShare) { return; }
    if (this.shareLink.trim().length === 0 && this.shareTitle.trim().length === 0 &&
      this.shareReason.trim().length === 0) {
      this.showShareSheet = false;
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: '内容还没发布',
      message: '确定要放弃这次分享吗？',
      buttons: [
        { text: '继续编辑', color: AppConstants.COLOR_PRIMARY },
        { text: '放弃', color: AppConstants.COLOR_DANGER }
      ]
    }).then((result) => {
      if (result.index === 1) {
        this.showShareSheet = false;
        this.clearShareDraft();
      }
    });
  }

  private clearShareDraft(): void {
    this.shareLink = '';
    this.shareTitle = '';
    this.shareReason = '';
    this.shareCategory = '治愈系';
    this.editingShareId = -1;
  }

  private startEditShare(item: VideoShare): void {
    if (item.id === undefined || item.sharer !== this.profile.nickname) {
      return;
    }
    this.editingShareId = item.id;
    this.shareLink = 'https://www.bilibili.com/video/' + item.bvid;
    this.shareTitle = item.title;
    this.shareReason = item.shareReason;
    this.shareCategory = item.category;
    this.showShareSheet = true;
  }

  private async startOrStopRest(): Promise<void> {
    if (this.resting) {
      await this.finishRest(false);
      return;
    }
    this.pageMode = 0;
    this.resting = true;
    this.remainingSeconds = 1200;
    this.restStartedAt = Date.now();
    if (!this.soundPlaying) { this.playSound(this.selectedSound); }
    const enabled: boolean = await this.liveView.start('休息剩余', this.remainingSeconds);
    if (!enabled) {
      this.showToast('实况窗当前不可用，休息倒计时会继续在应用内运行。');
    }
    this.timerId = setInterval(() => {
      this.remainingSeconds = Math.max(0, 1200 - Math.floor((Date.now() - this.restStartedAt) / 1000));
      if (this.remainingSeconds <= 0) {
        this.finishRest(true);
      } else {

        this.liveView.update('休息剩余', this.remainingSeconds, false);
      }
    }, 1000);
  }

  private async finishRest(completed: boolean): Promise<void> {
    if (!this.resting) { return; }
    this.resting = false;
    const elapsed: number = Math.max(0, Math.min(1200, Math.floor((Date.now() - this.restStartedAt) / 1000)));
    this.clearTimer();
    await this.ambient.stop().catch(() => {});
    if (elapsed > 0) {
      try { await DatabaseService.addTrainingRecord({ date: new Date().toISOString(), type: 'rest', duration: elapsed }); DatabaseService.notifyChanged(); }
      catch (reason) { this.showToast('休息已结束，但这次记录未能保存。'); }
    }
    await this.liveView.stop(
      completed,
      completed ? '休息完成，准备继续学习' : '休息提前结束'
    );
    this.remainingSeconds = 1200;
    if (completed) {
      this.showRestCompletion();
    } else {
      this.showToast('已经准备好，就带着轻松一点的状态继续吧。');
    }
  }

  private async showRestCompletion(): Promise<void> {
    HapticService.confirm();
    if (await MemeService.shouldShow('rest_complete')) {
      this.showMeme = true;
    }
    this.showToast('休息结束啦，带着恢复后的状态继续复习吧。');
  }

  private clearTimer(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private timerText(): string {
    const minutes: string = Math.floor(this.remainingSeconds / 60).toString().padStart(2, '0');
    const seconds: string = (this.remainingSeconds % 60).toString().padStart(2, '0');
    return minutes + ':' + seconds;
  }

  private confirmDelete(item: VideoShare): void {
    if (item.id === undefined || item.sharer !== this.profile.nickname) {
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: '删除我的分享',
      message: '删除后这条视频会从树洞墙移除，确定吗？',
      buttons: [
        { text: '保留', color: AppConstants.COLOR_TEXT_SECONDARY },
        { text: '删除', color: AppConstants.COLOR_DANGER }
      ]
    }).then((result) => {
      if (result.index === 1 && item.id !== undefined) {
        this.deleteShare(item.id);
      }
    });
  }

  private async deleteShare(id: number): Promise<void> {
    try {
      await DatabaseService.deleteVideoShare(id);
      await this.loadData();
      this.showToast('分享已删除。');
    } catch (reason) {
      this.showToast('刚才没有删除成功，再试一次？');
    }
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2500 });
  }

  build() {
    Stack() {
      if (this.resting) {
        this.RestRunningScreen()
      } else if (this.pageMode === 1) {
        this.TreeHoleScreen()
      } else {
        this.RestHomeScreen()
      }

      if (this.showMeme) {
        MemePopup({
          visible: $showMeme,
          asset: 'go_study',
          message: '休息好了吧？回去继续学，稳稳完成下一步。'
        })
      }

      if (this.showIntro) {
        this.RestIntroOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_old: Area, area: Area) => {
      this.viewportHeight = Number(area.height); this.viewportWidth = Number(area.width);
    })
    .bindContentCover($$this.showSoundPicker, this.SoundPickerCover())
    .bindSheet($$this.showShareSheet, this.ShareSheet(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      showClose: false,
      backgroundColor: '#F7FFFFFF',
      onWillDismiss: () => {
        this.cancelShare();
      }
    })
  }

  @Builder
  RestTopBar() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Image($rawfile('back_arrow.svg')).width(24).height(24)
      }
      .width(44).height(44).accessibilityText('返回')
      .backgroundColor('#B8FFFFFF')
      .border({ width: 1, color: '#DDE8D0' })
      .onClick(() => {
        if (this.pageMode === 1) {
          this.pageMode = 0;
        } else {
          this.confirmExit();
        }
      })

      Text(this.pageMode === 1 ? '大家的树洞' : '松风休息站')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2D4D25')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Blank().width(42).height(42)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  RestHomeScreen() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 160,
          colors: [['#FFFDF3', 0.0], ['#F5F8E5', 0.58], ['#EBF4E4', 1.0]]
        })
      Image($rawfile('kxq_rest_hero_tree_bench.png'))
        .width('100%')
        .height('76%')
        .objectFit(ImageFit.Cover)
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#52FFFFFF', 0.0], ['#00FFFFFF', 0.38], ['#24FFFDEE', 0.62], ['#F3FFFDF3', 0.84], ['#FFFFFDF3', 1.0]]
        })
      Column() {
        Row() {
          Button({ type: ButtonType.Circle }) {
            Image($rawfile('back_arrow.svg')).width(24).height(24)
          }.width(44).height(44).accessibilityText('返回').backgroundColor('#EFFFFFFF').accessibilityText('返回')
            .onClick(() => { this.confirmExit(); })
          Blank()
        }.width('100%').padding({ top: 10 })
        Text('松风休息站')
          .width('100%')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#294A24')
          .textAlign(TextAlign.Center)
          .margin({ top: 8 })
        Text('给自己一段有边界的放松时间')
          .width('100%')
          .fontSize(14)
          .fontColor('#617555')
          .textAlign(TextAlign.Center)
          .margin({ top: 10 })
        Blank().layoutWeight(1)
        Button('开始 20 分钟休息')
          .width('100%')
          .height(60)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_WHITE)
          .backgroundColor('#73A64A')
          .borderRadius(30)
          .shadow({ radius: 16, color: '#40769D3C', offsetY: 7 })
          .margin({ bottom: 18 })
          .onClick(() => {
            this.startOrStopRest();
          })
        this.RestQuickActions()

      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 20, right: 20, bottom: 4 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  RestRunningScreen() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 160,
          colors: [['#FFFDF3', 0.0], ['#F5F8E5', 0.56], ['#ECF4E7', 1.0]]
        })
      Image($rawfile('kxq_rest_leaf_light_decor.png'))
        .width('115%')
        .height(230)
        .objectFit(ImageFit.Contain)
        .opacity(0.7)
        .margin({ top: -28 })
      Image($rawfile('kxq_ui_rest_reference_branch.png'))
        .width(155)
        .height(178)
        .objectFit(ImageFit.Contain)
        .align(Alignment.TopStart)
        .margin({ top: 48, left: -10 })
        .opacity(0.74)
      Column({ space: 14 }) {
        this.RestTopBar()
        this.RestRunningPanel()
      }
      .width('100%')
      .height('100%')
      .padding({ left: 20, right: 20, top: 14, bottom: 18 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TreeHoleScreen() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 160,
          colors: [['#FFFDF5', 0.0], ['#F9FAED', 0.58], ['#EFF7E8', 1.0]]
        })
      Image($rawfile('kxq_rest_leaf_light_decor.png'))
        .width('120%')
        .height(220)
        .objectFit(ImageFit.Contain)
        .opacity(0.42)
        .margin({ top: -36 })
      Column() {
        this.TreeHoleHeader()
        Scroll() {
          this.TreeHoleSection()
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)

      }
      .width('100%')
      .height('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 4 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TreeHoleHeader() {
    Column({ space: 8 }) {
      Row() {
        Button({ type: ButtonType.Circle }) {
          Image($rawfile('back_arrow.svg')).width(24).height(24)
        }.width(44).height(44).accessibilityText('返回').backgroundColor('#EFFFFFFF').onClick(() => { this.pageMode = 0; })
        Text('大家的树洞').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#294A24')
          .layoutWeight(1).textAlign(TextAlign.Center)
        Button('推荐').height(44).fontSize(12).backgroundColor('#E8F4E3').fontColor('#35542A')
          .onClick(() => { this.showShareSheet = true; })
      }.width('100%')
      Text('精选 B 站公开内容 · 点击在 B 站观看').fontSize(12).fontColor('#6A7760')
    }.width('100%').padding({ bottom: 10 })
  }

  @Builder
  RestHeroPanel() {
    Stack() {
      Image($rawfile('kxq_scene_rest_lake_bench_wide.png'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .borderRadius(32)
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#ECFFFFFF', 0.0], ['#72FFFFFF', 0.42], ['#00FFFFFF', 0.74], ['#B8FFF9E8', 1.0]]
        })
        .borderRadius(32)
      Column({ space: 12 }) {
        Text('松风休息站')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#224B20')
        Text('给自己一段有边界的放松时间')
          .fontSize(14)
          .fontColor('#536B48')
        Blank()
        Button() {
          Row({ space: 10 }) {
            Image($rawfile('kxq_adjust_rest_feature.png'))
              .width(26)
              .height(26)
              .objectFit(ImageFit.Contain)
            Text('开始 20 分钟休息')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppConstants.COLOR_WHITE)
          }
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height(62)
        .backgroundColor('#78A943')
        .borderRadius(31)
        .shadow({ radius: 16, color: '#40769D3C', offsetY: 7 })
        .onClick(() => {
          this.startOrStopRest();
        })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 26, right: 26, top: 48, bottom: 24 })
    }
    .width('100%')
    .height(520)
    .border({ width: 1, color: '#E6EAD7' })
    .borderRadius(32)
    .shadow({ radius: 24, color: '#26839A68', offsetY: 10 })
  }

  @Builder
  RestRunningPanel() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 155,
          colors: [['#FCFFF5', 0.0], ['#F0F7DC', 0.58], ['#EAF5ED', 1.0]]
        })
        .border({ width: 1, color: '#E0EBCF' })
        .borderRadius(34)
      Image($rawfile('kxq_rest_leaf_light_decor.png'))
        .width('120%')
        .height(220)
        .objectFit(ImageFit.Contain)
        .opacity(0.72)
        .margin({ top: -34 })
      Column({ space: this.viewportHeight < 700 ? 8 : 14 }) {
        Text('休息进行中')
          .fontSize(15)
          .fontColor('#4F6D47')
          .padding({ left: 22, right: 22, top: 8, bottom: 8 })
          .backgroundColor('#B8FFFFFF')
          .border({ width: 1, color: '#DAE7CE' })
          .borderRadius(22)
        Text(this.timerText())
          .fontSize(this.viewportHeight < 700 ? 48 : 60)
          .fontWeight(FontWeight.Regular)
          .fontColor('#294D22')
        Text('远离打扰，专注休息')
          .fontSize(14)
          .fontColor('#657558')
        this.CurrentSoundCard()
        Row() {
          Text('休息进度')
            .fontSize(12)
            .fontColor('#657558')
            .layoutWeight(1)
          Text(Math.round((1200 - this.remainingSeconds) / 12).toString() + '%')
            .fontSize(12)
            .fontColor('#657558')
        }
        .width('100%')
        Progress({
          value: 1200 - this.remainingSeconds,
          total: 1200,
          type: ProgressType.Linear
        })
          .width('100%')
          .height(8)
          .color('#81A94A')
          .backgroundColor('#DDE8C7')
        Text('允许自己慢下来，也是一种向前走的方式。')
          .fontSize(14)
          .fontColor('#4E5F43')
          .textAlign(TextAlign.Center)
          .lineHeight(21)
        Button('结束休息')
          .width('82%')
          .height(56)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#294D22')
          .backgroundColor('#F8FFFFFF')
          .border({ width: 1.5, color: '#82A75D' })
          .borderRadius(28)
          .onClick(() => {
            this.startOrStopRest();
          })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    }
    .width('100%')
    .layoutWeight(1)
    .shadow({ radius: 22, color: '#20839A68', offsetY: 9 })
  }

  @Builder
  CurrentSoundCard() {
    Row({ space: 12 }) {
      Image($rawfile('kxq_extra_music_note.png')).width(40).height(40).objectFit(ImageFit.Contain)
      Column({ space: 6 }) {
        Text(this.soundName()).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#294D22')
        Text(this.soundLoading ? '声音准备中…' : (this.soundPlaying ? '正在循环播放 · 离线环境声' : '已暂停 · 点击播放'))
          .fontSize(11).fontColor('#657558')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start).onClick(() => { this.showSoundPicker = true; })
      Button(this.soundPlaying ? '暂停' : '播放').height(44).fontSize(12).enabled(!this.soundLoading)
        .fontColor('#315B29').backgroundColor('#F6FFF3').onClick(() => { this.playSound(this.selectedSound); })
    }.width('100%').height(92).padding(14).backgroundColor('#E6F0DE').borderRadius(20)
  }

  @Builder
  SoundPickerCover() {
    Column({ space: 16 }) {
      Row() {
        Text('安静陪伴').fontSize(22).fontWeight(FontWeight.Bold).layoutWeight(1)
        Button('完成').height(44).fontSize(13).onClick(() => { this.showSoundPicker = false; })
      }.width('100%')
      Text('三段本地合成环境声，离线可听。选择喜欢的声音，让它慢慢循环。').fontSize(13).fontColor('#657558').width('100%')
      this.SoundChoice('ocean', '海浪白噪音', '柔和的潮汐起伏', 'kxq_rest_sound_sea.png')
      this.SoundChoice('rain', '窗边雨声', '细密均匀的雨声', 'kxq_rest_sound_rain_desk.png')
      this.SoundChoice('forest', '林间风声', '低缓的风与树叶声', 'kxq_rest_sound_tree_wind.png')
      Text('播放音量 ' + this.soundVolume.toString() + '%').fontSize(14).fontColor('#35542A').width('100%')
      Slider({ value: this.soundVolume, min: 0, max: 100, step: 1 })
        .onChange((value: number) => { this.soundVolume = value; this.ambient.setVolume(value / 100); })
      Text('离开休息站或进入后台后会停止播放。').fontSize(12).fontColor('#657558').width('100%')
    }.width('100%').height('100%').padding({ left: 20, right: 20, top: 18, bottom: 20 }).backgroundColor('#F6FAF0')
  }

  @Builder
  SoundChoice(key: string, title: string, note: string, asset: string) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Image($rawfile(asset)).width(76).height(60).objectFit(ImageFit.Cover).borderRadius(12)
        Column({ space: 6 }) {
          Text(title).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#35542A')
          Text(note).fontSize(11).fontColor('#657558')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(this.soundLoading && this.selectedSound === key ? '准备中' : (this.soundPlaying && this.selectedSound === key ? '暂停' : '播放'))
          .fontSize(12).fontColor('#4B814C')
      }.width('100%')
    }.width('100%').height(92).padding(12).backgroundColor(Color.White).borderRadius(20).enabled(!this.soundLoading)
      .onClick(() => { this.playSound(key); })
  }

  @Builder
  RestQuickActions() {
    Row({ space: 12 }) {
      this.RestMiniAction($rawfile('kxq_game_reward_card_art.png'), '治愈视频', '暖心短片')
      this.RestMiniAction($rawfile('kxq_extra_music_note.png'), '安静陪伴', '白噪音')
      this.RestMiniAction($rawfile('kxq_rest_wood_sign_blank.png'), '大家的树洞', '分享与倾听')
    }
    .width('100%')
    .margin({ top: 2 })
  }

  @Builder
  RestMiniAction(icon: Resource, title: string, subtitle: string) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 5 }) {
        Image(icon)
          .width(32)
          .height(32)
          .objectFit(ImageFit.Contain)
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#263D22')
          .maxLines(1)
        Text(subtitle)
          .fontSize(11)
          .fontColor('#6A7760')
          .maxLines(1)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .layoutWeight(1)
    .height(88)
    .padding(0)
    .backgroundColor('#EFFFFFFF')
    .border({ width: 1, color: '#E2E8D8' })
    .borderRadius(22)
    .shadow({ radius: 12, color: '#12839A68', offsetY: 4 })
    .accessibilityText(title + '，' + subtitle)
    .onClick(() => {
      HapticService.light();
      if (title === '安静陪伴') { this.showSoundPicker = true; }
      else { this.pageMode = 1; this.treeHoleTab = title === '治愈视频' ? 0 : 1; }
    })
  }

  private visibleVideos(): VideoShare[] {
    const result: VideoShare[] = this.videos.slice();
    if (this.treeHoleTab === 1) { result.sort((a: VideoShare, b: VideoShare) => (b.views ?? 0) - (a.views ?? 0)); }
    else { result.sort((a: VideoShare, b: VideoShare) => {
      const first: number = AppConstants.PRESET_VIDEOS.findIndex((item: VideoShare) => item.bvid === a.bvid);
      const second: number = AppConstants.PRESET_VIDEOS.findIndex((item: VideoShare) => item.bvid === b.bvid);
      return first - second;
    }); }
    return result;
  }

  private videoDuration(seconds: number): string {
    return Math.floor(seconds / 60).toString() + ':' + (seconds % 60).toString().padStart(2, '0');
  }

  private presetVideo(item: VideoShare): boolean {
    return AppConstants.PRESET_VIDEOS.some((preset: VideoShare) => preset.bvid === item.bvid);
  }

  @Builder
  TreeHoleSection() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        this.TreeHoleChip('今日温暖', 0)
        this.TreeHoleChip('大家都在看', 1)
      }.width('100%')
      Text(this.treeHoleTab === 0 ? '治愈短片与自然风景，慢慢看。' : '按收录时的 B 站播放量排序，非实时榜单。')
        .fontSize(11).fontColor('#657558').width('100%')
      if (this.videos.length === 0) { Text('暂时没有视频，点击上方推荐添加 B 站链接。').fontSize(13).padding(24) }
      ForEach(this.visibleVideos(), (item: VideoShare) => { this.TreeHoleCard(item) }, (item: VideoShare) => item.bvid)
    }.width('100%')
  }

  @Builder
  TreeHoleChip(label: string, tab: number) {
    Button(label).layoutWeight(1).height(44).fontSize(14)
      .fontColor(this.treeHoleTab === tab ? '#315B29' : '#6A7760')
      .backgroundColor(this.treeHoleTab === tab ? '#E1EFDA' : '#F2F5ED')
      .onClick(() => { this.treeHoleTab = tab; })
  }

  @Builder
  TreeHoleCard(item: VideoShare) {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.BottomEnd }) {
          if (this.presetVideo(item)) {
            Image($rawfile('bili_' + item.bvid + '.jpg')).width('100%').height('100%').objectFit(ImageFit.Cover)
          } else {
            Image(item.coverUrl).alt($rawfile('kxq_scene_rest_lake_bench_wide.png')).width('100%').height('100%').objectFit(ImageFit.Cover)
          }
          Text(item.duration !== undefined ? this.videoDuration(item.duration) : 'B站视频')
            .fontSize(10).fontColor(Color.White).padding(4).backgroundColor('#99000000').borderRadius(6).margin(5)
        }.width(128).height(84).borderRadius(12).clip(true)
        Column({ space: 5 }) {
          Text(item.title).fontSize(14).fontWeight(FontWeight.Bold).fontColor('#263D22').maxLines(2)
          Text(item.author !== undefined ? 'UP：' + item.author : 'B站公开视频').fontSize(11).fontColor('#657558').maxLines(1)
          Text('在 B 站观看').fontSize(11).fontColor('#477D4B')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').onClick(() => { this.openVideo(item); })
      Text(item.shareReason).fontSize(12).fontColor('#657558').width('100%').maxLines(2)
      if (!this.presetVideo(item) && item.sharer === this.profile.nickname) {
        Row({ space: 10 }) {
          Button('编辑').height(44).fontSize(12).onClick(() => { this.startEditShare(item); })
          Button('删除').height(44).fontSize(12).onClick(() => { this.confirmDelete(item); })
        }.width('100%').justifyContent(FlexAlign.End)
      }
    }.width('100%').padding(12).backgroundColor(Color.White).borderRadius(20)
  }

  @Builder
  RestActionBar() {
    Row({ space: 10 }) {
      Image($rawfile('kxq_icon_rest.png'))
        .width(34)
        .height(34)
        .objectFit(ImageFit.Contain)
      Column({ space: 2 }) {
        Text(this.resting ? this.timerText() : '开始休息 · 20 分钟')
          .fontSize(this.resting ? 22 : 15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#263D22')
        Text(this.resting ? '到点提醒你回到学习' : '一段有边界的恢复时间')
          .fontSize(11)
          .fontColor('#6A7760')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Button(this.resting ? '结束' : '开始')
        .height(42)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppConstants.COLOR_WHITE)
        .backgroundColor(this.resting ? '#F27768' : '#78A943')
        .borderRadius(21)
        .onClick(() => {
          this.startOrStopRest();
        })
    }
    .width('calc(100% - 32vp)')
    .height(72)
    .padding({ left: 14, right: 10 })
    .margin({ right: 16, bottom: 14 })
    .backgroundColor('#F2FFFFFF')
    .backgroundBlurStyle(BlurStyle.Thick)
    .border({ width: 1, color: '#E4EAD8' })
    .borderRadius(26)
    .shadow({ radius: 18, color: '#1D839A68', offsetY: 7 })
  }

  @Builder
  RestIntroOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#730A1730')
        .backgroundBlurStyle(BlurStyle.Thin)

      Column({ space: 14 }) {
        Image($rawfile('meme_breakdown.png'))
          .width('100%')
          .height(210)
          .objectFit(ImageFit.Cover)
          .borderRadius({ topLeft: 26, topRight: 26 })
        Column({ space: 9 }) {
          Text('这里是“休息一下”')
            .width('100%')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
          Text('给大脑一段有边界的 20 分钟恢复时间。你可以看看大家分享的治愈视频，倒计时结束后，应用会提醒你回到学习。')
            .width('100%')
            .fontSize(14)
            .lineHeight(22)
            .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.clock'))
              .fontSize(18)
              .fontColor([AppConstants.COLOR_PRIMARY])
            Text('休息不是逃避，是为了更稳地继续')
              .fontSize(12)
              .fontColor(AppConstants.COLOR_PRIMARY)
          }
          .width('100%')
          .padding(10)
          .backgroundColor('#12007DFF')
          .borderRadius(12)
          Button('知道了，先看看')
            .width('100%')
            .height(48)
            .fontSize(15)
            .fontColor(AppConstants.COLOR_WHITE)
            .backgroundColor(AppConstants.COLOR_PRIMARY)
            .onClick(() => {
              this.showIntro = false;
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 18, right: 18, bottom: 18 })
      }
      .width('calc(100% - 44vp)')
      .backgroundColor('#F7FFFFFF')
      .backgroundBlurStyle(BlurStyle.Thick)
      .borderRadius(26)
      .shadow({ radius: 24, color: '#33000A1C', offsetY: 10 })
      .transition(
        TransitionEffect.scale({ x: 0.88, y: 0.88 })
          .combine(TransitionEffect.OPACITY)
          .animation({ duration: 260, curve: Curve.Friction })
      )
    }
    .width('100%')
    .height('100%')
    .zIndex(160)
  }

  @Builder
  ShareSheet() {
    Column({ space: 14 }) {
      Row() {
        Text(this.editingShareId > 0 ? '编辑我的收录' : '收录治愈我的视频')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
          .layoutWeight(1)
        Button('取消')
          .enabled(!this.savingShare)
          .fontSize(13)
          .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.cancelShare();
          })
      }
      .width('100%')

      TextInput({ placeholder: 'B站视频链接或BV号', text: this.shareLink })
        .width('100%')
        .height(46)
        .backgroundColor('#99F0F5FF')
        .borderRadius(12)
        .onChange((value: string) => {
          this.shareLink = value;
        })
      Text('标题与封面会从 B 站读取。收录和感想保存在本机，暂不公开发布。')
        .width('100%').fontSize(12).fontColor(AppConstants.COLOR_TEXT_SECONDARY)
      TextArea({ placeholder: '它为什么治愈了你？', text: this.shareReason })
        .width('100%')
        .height(82)
        .backgroundColor('#99F0F5FF')
        .borderRadius(12)
        .onChange((value: string) => {
          this.shareReason = value;
        })
      Row({ space: 12 }) {
        Radio({ value: '治愈系', group: 'videoCategory' })
          .checked(this.shareCategory === '治愈系')
          .onChange(() => {
            this.shareCategory = '治愈系';
          })
        Text('治愈系')
          .fontSize(14)
          .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
        Radio({ value: '搞笑类', group: 'videoCategory' })
          .checked(this.shareCategory === '搞笑类')
          .onChange(() => {
            this.shareCategory = '搞笑类';
          })
        Text('搞笑类')
          .fontSize(14)
          .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
      }
      .width('100%')
      Button(this.savingShare ? '正在核实…' : (this.editingShareId > 0 ? '保存修改' : '收录到本机树洞'))
        .enabled(!this.savingShare)
        .width('100%')
        .height(48)
        .fontColor(AppConstants.COLOR_WHITE)
        .backgroundColor(AppConstants.COLOR_PRIMARY)
        .onClick(() => {
          this.saveShare();
        })
    }
    .width('100%')
    .padding(20)
  }
}
