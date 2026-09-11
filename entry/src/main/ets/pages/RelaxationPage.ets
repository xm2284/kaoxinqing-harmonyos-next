import { common } from '@kit.AbilityKit';
import { router, window } from '@kit.ArkUI';
import { AppConstants, BreathingMode, TrainingRecord } from '../common/DataModels';
import { IntentService } from '../service/IntentService';
import { LiveViewService } from '../service/LiveViewService';
import { BreathingModeService } from '../services/BreathingModeService';
import { DatabaseService } from '../services/DatabaseService';
import { HapticService } from '../services/HapticService';

@Component
struct BreathingCanvas {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @Prop @Watch('redraw') progress: number = 0;
  @Prop @Watch('redraw') phase: string = '准备';

  redraw(): void {
    this.draw();
  }

  private draw(): void {
    const ctx: CanvasRenderingContext2D = this.context;
    const size: number = 260;
    const center: number = 130;
    const easedProgress: number = this.progress < 0.5 ?
      2 * this.progress * this.progress :
      1 - Math.pow(-2 * this.progress + 2, 2) / 2;
    const radius: number = 48 + easedProgress * 64;
    ctx.clearRect(0, 0, size, size);

    for (let ring: number = 0; ring < 3; ring++) {
      ctx.beginPath();
      ctx.arc(center, center, 88 + ring * 14, 0, Math.PI * 2);
      ctx.strokeStyle = ring === 0 ? '#24FFFFFF' : '#14FFFFFF';
      ctx.lineWidth = 1;
      ctx.stroke();
    }

    const gradient: CanvasGradient =
      ctx.createRadialGradient(center - 22, center - 26, 8, center, center, radius);
    if (this.phase === '屏息') {
      gradient.addColorStop(0, '#EEE9FF');
      gradient.addColorStop(0.55, '#A99BF4');
      gradient.addColorStop(1, '#6D5DCC');
    } else if (this.phase === '呼气') {
      gradient.addColorStop(0, '#E8F1FF');
      gradient.addColorStop(0.55, '#91B5ED');
      gradient.addColorStop(1, '#5278BE');
    } else {
      gradient.addColorStop(0, '#F1F7FF');
      gradient.addColorStop(0.55, '#8FC4FF');
      gradient.addColorStop(1, '#3E7FDB');
    }
    ctx.beginPath();
    ctx.arc(center, center, radius, 0, Math.PI * 2);
    ctx.shadowColor = '#4D86D9';
    ctx.shadowBlur = 24;
    ctx.fillStyle = gradient;
    ctx.fill();
    ctx.shadowBlur = 0;

    ctx.beginPath();
    ctx.arc(center, center, Math.max(8, radius - 10), 0, Math.PI * 2);
    ctx.strokeStyle = '#99FFFFFF';
    ctx.lineWidth = 1.5;
    ctx.stroke();
  }

  build() {
    Canvas(this.context)
      .width(260)
      .height(260)
      .onReady(() => {
        this.draw();
      })
  }
}

@Entry
@Component
struct RelaxationPage {
  @State viewportHeight: number = 760;
  @State viewportWidth: number = 390;
  @State records: TrainingRecord[] = [];
  @State running: boolean = false;
  @State paused: boolean = false;
  @State phase: string = '准备';
  @State phaseRemaining: number = 4;
  @State round: number = 1;
  @State elapsed: number = 0;
  @State breathProgress: number = 0;
  @State completionFeeling: string = '';
  @State editingRecordId: number = -1;
  @State editingDurationText: string = '';
  @State activeModeId: string = '478';
  private readonly modes: BreathingMode[] = BreathingModeService.modes();
  private timerId: number = -1;
  private lastTickAt: number = 0;
  private secondAccumulator: number = 0;
  private phaseElapsedMs: number = 0;
  private liveView: LiveViewService = new LiveViewService();

  aboutToAppear(): void {
    this.setImmersive(true);
    this.loadRecords();
  }

  aboutToDisappear(): void {
    this.clearTimer();
    this.liveView.stop(false);
    this.setImmersive(false);
  }

  onBackPress(): boolean {
    this.confirmExit();
    return true;
  }

  private setImmersive(enabled: boolean): void {
    const context: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext;
    window.getLastWindow(context).then((appWindow: window.Window) => {
      const bars: Array<'status' | 'navigation'> =
        enabled ? ['navigation'] : ['status', 'navigation'];
      appWindow.setWindowSystemBarEnable(bars).catch(() => {
        console.info('System bar state unavailable');
      });
    }).catch(() => {
      console.info('Window unavailable');
    });
  }

  private async loadRecords(): Promise<void> {
    try {
      const allRecords: TrainingRecord[] = await DatabaseService.getAllTrainingRecords();
      const breathingRecords: TrainingRecord[] = [];
      for (let index: number = 0; index < allRecords.length; index++) {
        if (allRecords[index].type === 'breathing') {
          breathingRecords.push(allRecords[index]);
        }
      }
      this.records = breathingRecords;
    } catch (reason) {
      this.showToast('训练记录暂时没有加载出来。');
    }
  }

  private startTraining(): void {
    if (this.running) {
      this.paused = !this.paused;
      this.lastTickAt = Date.now();
      this.liveView.update(this.phase, this.phaseRemaining, this.paused);
      return;
    }
    this.running = true;
    this.paused = false;
    this.completionFeeling = '';
    this.elapsed = 0;
    this.round = 1;
    this.lastTickAt = Date.now();
    this.secondAccumulator = 0;
    this.phaseElapsedMs = 0;
    this.phase = '吸气';
    this.phaseRemaining = this.selectedMode().inhaleSeconds;
    this.breathProgress = 0;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    IntentService.shareBreathingIntent(context, this.selectedMode().name);
    this.liveView.start(this.phase, this.phaseRemaining).then((enabled: boolean) => {
      if (!enabled) {
        console.info('Live view unavailable; continuing in-app breathing session.');
      }
    });
    this.timerId = setInterval(() => {
      this.tick();
    }, 32);
  }

  private tick(): void {
    const now: number = Date.now();
    const delta: number = Math.max(0, Math.min(240, now - this.lastTickAt));
    this.lastTickAt = now;
    if (this.paused || !this.running) {
      return;
    }
    this.secondAccumulator += delta;
    this.phaseElapsedMs += delta;
    const durationMs: number = this.phaseDurationMs();
    this.updateBreathingProgress(durationMs);
    const remaining: number = Math.max(0, Math.ceil((durationMs - this.phaseElapsedMs) / 1000));
    if (remaining !== this.phaseRemaining) {
      this.phaseRemaining = remaining;
    }
    if (this.phaseElapsedMs >= durationMs) {
      this.advanceBreathingPhase();
    }
    while (this.secondAccumulator >= 1000 && this.running) {
      this.secondAccumulator -= 1000;
      this.elapsed++;
      this.liveView.update(this.phase, this.phaseRemaining, false);
    }
  }

  private phaseDurationMs(): number {
    if (this.phase === '吸气') {
      return this.selectedMode().inhaleSeconds * 1000;
    }
    if (this.phase === '屏息') {
      return this.selectedMode().holdSeconds * 1000;
    }
    return this.selectedMode().exhaleSeconds * 1000;
  }

  private updateBreathingProgress(durationMs: number): void {
    const ratio: number = Math.min(1, this.phaseElapsedMs / durationMs);
    if (this.phase === '吸气') {
      this.breathProgress = ratio;
    } else if (this.phase === '屏息') {
      this.breathProgress = 1;
    } else {
      this.breathProgress = 1 - ratio;
    }
  }

  private advanceBreathingPhase(): void {
    if (this.phase === '吸气') {
      this.phase = '屏息';
      this.phaseRemaining = this.selectedMode().holdSeconds;
      this.breathProgress = 1;
      this.phaseElapsedMs = 0;
      return;
    }
    if (this.phase === '屏息') {
      this.phase = '呼气';
      this.phaseRemaining = this.selectedMode().exhaleSeconds;
      this.breathProgress = 1;
      this.phaseElapsedMs = 0;
      return;
    }
    if (this.round >= this.selectedMode().rounds) {
      this.completeTraining();
      return;
    }
    this.round++;
    this.phase = '吸气';
    this.phaseRemaining = this.selectedMode().inhaleSeconds;
    this.breathProgress = 0;
    this.phaseElapsedMs = 0;
  }

  private selectedMode(): BreathingMode {
    for (let index: number = 0; index < this.modes.length; index++) {
      if (this.modes[index].id === this.activeModeId) {
        return this.modes[index];
      }
    }
    return this.modes[0];
  }

  private async completeTraining(): Promise<void> {
    if (!this.running) {
      return;
    }
    this.clearTimer();
    this.running = false;
    this.paused = false;
    this.phase = '训练完成';
    this.breathProgress = 0.4;
    this.secondAccumulator = 0;
    this.phaseElapsedMs = 0;
    await this.liveView.stop(true);
    const record: TrainingRecord = {
      date: new Date().toISOString(),
      type: 'breathing',
      duration: this.elapsed
    };
    try {
      await DatabaseService.addTrainingRecord(record);
      await this.loadRecords();
    } catch (reason) {
      this.showToast('训练完成了，但记录没有保存成功。');
    }
  }

  private clearTimer(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private confirmExit(): void {
    if (!this.running) {
      router.back();
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: '训练还没完成',
      message: '确定要结束这次训练吗？',
      buttons: [
        { text: '继续训练', color: AppConstants.COLOR_PRIMARY },
        { text: '结束', color: AppConstants.COLOR_DANGER }
      ]
    }).then((result) => {
      if (result.index === 1) {
        this.clearTimer();
        this.liveView.stop(false);
        router.back();
      }
    });
  }

  private confirmDelete(item: TrainingRecord): void {
    if (item.id === undefined) {
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: '删除训练记录',
      message: '确定删除这条训练记录吗？',
      buttons: [
        { text: '保留', color: AppConstants.COLOR_TEXT_SECONDARY },
        { text: '删除', color: AppConstants.COLOR_DANGER }
      ]
    }).then((result) => {
      if (result.index === 1 && item.id !== undefined) {
        this.deleteRecord(item.id);
      }
    });
  }

  private startEditRecord(item: TrainingRecord): void {
    if (item.id === undefined) {
      return;
    }
    this.editingRecordId = item.id;
    this.editingDurationText = Math.max(1, Math.round(item.duration / 60)).toString();
  }

  private async saveRecordEdit(item: TrainingRecord): Promise<void> {
    if (item.id === undefined) {
      return;
    }
    const minutes: number = Number(this.editingDurationText);
    if (!Number.isFinite(minutes) || minutes <= 0 || minutes > 180) {
      this.showToast('请输入 1 到 180 之间的训练分钟数。');
      return;
    }
    item.type = 'breathing';
    item.duration = Math.round(minutes * 60);
    try {
      await DatabaseService.updateTrainingRecord(item);
      this.editingRecordId = -1;
      this.editingDurationText = '';
      await this.loadRecords();
      this.showToast('训练记录已更新。');
    } catch (reason) {
      this.showToast('刚才没有保存成功，再试一次？');
    }
  }

  private async deleteRecord(id: number): Promise<void> {
    try {
      await DatabaseService.deleteTrainingRecord(id);
      await this.loadRecords();
      this.showToast('训练记录已删除。');
    } catch (reason) {
      this.showToast('刚才没有删除成功，再试一次？');
    }
  }

  private typeName(type: string): string {
    return '4-7-8 呼吸';
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2500 });
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#D4EEFF', 0.0], ['#EAF8FF', 0.46], ['#B9E2FC', 1.0]]
        })

      Image($rawfile('kxq_breath_lake_scene.png'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(0.53)

      Image($rawfile('kxq_breath_leaves.png'))
        .width(116)
        .height(116)
        .objectFit(ImageFit.Contain)
        .opacity(0.5)
        .align(Alignment.TopEnd)
        .margin({ top: 98, right: -26 })

      Image($rawfile('kxq_breath_leaves.png'))
        .width(110)
        .height(110)
        .objectFit(ImageFit.Contain)
        .opacity(0.62)
        .align(Alignment.BottomStart)
        .margin({ left: -32, bottom: 128 })

      Column() {
        this.TopBar()
        if (this.phase === '训练完成') {
          this.CompletionPage()
        } else {
          this.BreathingSession()
        }
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_old: Area, area: Area) => {
      this.viewportHeight = Number(area.height); this.viewportWidth = Number(area.width);
    })
  }

  @Builder
  BreathingSession() {
    Column({ space: 0 }) {
      this.BreathHeader()
      this.BreathingVisual()
      this.RoundBadge()
      this.ProgressLine()
      this.TimeRemaining()
      this.PrimaryBreathButton()
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 20, right: 20, bottom: 16 })
  }

  @Builder
  TopBar() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Image($rawfile('back_arrow.svg')).width(24).height(24)
      }
      .width(44).height(44).accessibilityText('返回')
      .backgroundColor('#F6FFFFFF')
      .border({ width: 1, color: '#D8ECFA' })
      .shadow({ radius: 14, color: '#1C6BA6D8', offsetY: 4 })
      .onClick(() => {
        this.confirmExit();
      })

      Blank()
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 0 })
  }

  @Builder
  BreathHeader() {
    Column({ space: 7 }) {
      Text('云息呼吸')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#143B68')
        .textAlign(TextAlign.Center)
        .maxLines(1)
      Text('跟随呼吸，慢下来，感受此刻的自己')
        .fontSize(14)
        .fontColor('#47627D')
        .textAlign(TextAlign.Center)
        .maxLines(2)
    }
    .width('100%')
    .padding({ top: 10, bottom: 8 })
  }

  @Builder
  BreathingVisual() {
    Stack({ alignContent: Alignment.Center }) {
      Image($rawfile('kxq_breath_water_ripple.png'))
        .width(Math.min(280, this.viewportWidth - 56))
        .height(110)
        .objectFit(ImageFit.Contain)
        .opacity(this.running ? 0.78 : 0.5)
        .margin({ top: Math.min(190, this.viewportHeight * 0.22) })

      Image($rawfile('kxq_breath_light_ring.png'))
        .width(Math.min(264, this.viewportHeight * 0.34, this.viewportWidth - 64))
        .height(Math.min(264, this.viewportHeight * 0.34, this.viewportWidth - 64))
        .objectFit(ImageFit.Contain)
        .opacity(0.5)
        .scale({
          x: 0.86 + this.breathProgress * 0.18,
          y: 0.86 + this.breathProgress * 0.18
        })
        .animation({ duration: 260, curve: Curve.EaseInOut })

      Image($rawfile('kxq_breath_lake_bubble.png'))
        .width(Math.min(226, this.viewportHeight * 0.29, this.viewportWidth - 88))
        .height(Math.min(226, this.viewportHeight * 0.29, this.viewportWidth - 88))
        .objectFit(ImageFit.Contain)
        .scale({
          x: 0.82 + this.breathProgress * 0.26,
          y: 0.82 + this.breathProgress * 0.26
        })
        .animation({ duration: 260, curve: Curve.EaseInOut })

      if (!this.running && this.phase === '准备') {
        Image($rawfile('kxq_breath_cloud_bubble.png'))
          .width(164)
          .height(164)
          .objectFit(ImageFit.Contain)
          .opacity(0.9)
      }

      Column({ space: 8 }) {
        Text(this.running ? this.phase : '吸气')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1D67B0')
        Text(this.running ? this.phaseRemaining.toString().padStart(2, '0') : '03')
          .fontSize(52)
          .fontWeight(FontWeight.Regular)
          .fontColor('#1D67B0')
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .onClick(() => {
      if (this.running) {
        this.startTraining();
      }
    })
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => {
          if (this.running) {
            this.confirmExit();
          }
        })
    )
  }

  @Builder
  RoundBadge() {
    Row({ space: 8 }) {
      Text('第 ' + this.round.toString() + ' / ' + this.selectedMode().rounds.toString() + ' 轮')
        .fontSize(19)
        .fontWeight(FontWeight.Medium)
        .fontColor('#164878')
      Image($rawfile('kxq_breath_leaves.png'))
        .width(28)
        .height(28)
        .objectFit(ImageFit.Contain)
    }
    .justifyContent(FlexAlign.Center)
    .height(48)
    .padding({ left: 28, right: 22 })
    .backgroundColor('#E6FFFFFF')
    .border({ width: 1, color: '#D7EBF8' })
    .borderRadius(26)
    .shadow({ radius: 12, color: '#1668A6C8', offsetY: 4 })
  }

  @Builder
  ProgressLine() {
    Stack({ alignContent: Alignment.Start }) {
      Column()
        .width('100%')
        .height(2)
        .backgroundColor('#6C8FC2D9')
        .borderRadius(1)
      Column()
        .width(((this.round - 1 + this.breathProgress) / this.selectedMode().rounds * 100).toString() + '%')
        .height(2)
        .backgroundColor('#1D7DCC')
        .borderRadius(1)
    }
    .width('100%')
    .height(2)
    .margin({ top: 14, bottom: 10 })
  }

  @Builder
  TimeRemaining() {
    Column() {
      Text('剩余 ' + this.formatRemainingSeconds())
        .fontSize(21)
        .fontWeight(FontWeight.Medium)
        .fontColor('#164878')
        .maxLines(1)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 4, bottom: 16 })
  }

  @Builder
  PrimaryBreathButton() {
    Button(this.running ? '▣  结束练习' : '开始练习')
      .width('74%')
      .height(48)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor('#1D7DCC')
      .backgroundColor('#F2FFFFFF')
      .border({ width: 1, color: '#D8ECFA' })
      .borderRadius(28)
      .shadow({ radius: 18, color: '#1A6BA6D8', offsetY: 6 })
      .onClick(() => {
        if (this.running) {
          this.completeTraining();
        } else {
          this.startTraining();
        }
      })
  }

  @Builder
  CompletionPage() {
    Column({ space: 0 }) {
      Stack({ alignContent: Alignment.Center }) {
        Image($rawfile('kxq_breath_light_ring.png'))
          .width(168)
          .height(168)
          .objectFit(ImageFit.Contain)
          .opacity(0.42)
        Image($rawfile('kxq_breath_cloud_bubble.png'))
          .width(130)
          .height(130)
          .objectFit(ImageFit.Contain)
      }
      .width('100%')
      .height(Math.min(168, this.viewportHeight * 0.22))
      .margin({ top: 10 })

      Text('呼吸结束啦')
        .fontSize(23)
        .fontWeight(FontWeight.Bold)
        .fontColor('#174F90')
        .margin({ top: 20 })
      Text('现在感觉有没有轻松一点？')
        .fontSize(16)
        .fontColor('#426C9E')
        .margin({ top: 10, bottom: 18 })

      this.FeelingOption('😌', '轻松很多')
      this.FeelingOption('😐', '一点点')
      this.FeelingOption('😣', '还很紧张')
      if (this.completionFeeling.length > 0) {
        Text('已记录：' + this.completionFeeling + '，下次可以继续观察变化。')
          .fontSize(12)
          .fontColor('#1D7DCC')
          .padding({ top: 8, bottom: 8 })
          .opacity(1)
          .animation({ duration: 220, curve: Curve.EaseOut })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .layoutWeight(1)
    .padding({ left: 24, right: 24, bottom: 16 })
  }

  @Builder
  FeelingOption(emoji: string, label: string) {
    Row({ space: 18 }) {
      Text(emoji)
        .fontSize(27)
      Text(label)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#235B9F')
        .layoutWeight(1)
      if (this.completionFeeling === label) {
        Text('✓')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1D7DCC')
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: 28, right: 24 })
    .margin({ bottom: 10 })
    .backgroundColor(this.completionFeeling === label ? '#F0FBFF' : '#E6FFFFFF')
    .border({ width: 1, color: this.completionFeeling === label ? '#78BCEB' : '#D3E8F8' })
    .borderRadius(32)
    .shadow({ radius: 12, color: '#1668A61A', offsetY: 5 })
    .scale({ x: this.completionFeeling === label ? 1.02 : 1, y: this.completionFeeling === label ? 1.02 : 1 })
    .animation({ duration: 180, curve: Curve.EaseOut })
    .onClick(() => {
      this.completionFeeling = label;
      HapticService.light();
      this.showToast('已记录你的状态：' + label);
    })
  }

  private formatRemainingSeconds(): string {
    const totalSeconds: number =
      Math.max(0, (this.selectedMode().rounds - this.round) *
      (this.selectedMode().inhaleSeconds + this.selectedMode().holdSeconds + this.selectedMode().exhaleSeconds) +
        this.phaseRemaining);
    const minutes: number = Math.floor(totalSeconds / 60);
    const seconds: number = totalSeconds % 60;
    return minutes.toString().padStart(2, '0') + ':' + seconds.toString().padStart(2, '0');
  }

  @Builder
  ModeSelector() {
    Row({ space: 8 }) {
      ForEach(this.modes, (mode: BreathingMode) => {
        Column({ space: 3 }) {
          Text(mode.name)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.activeModeId === mode.id ? '#143B68' : '#5E7893')
            .maxLines(1)
          Text(mode.inhaleSeconds.toString() + '-' + mode.holdSeconds.toString() + '-' +
          mode.exhaleSeconds.toString())
            .fontSize(10)
            .fontColor(this.activeModeId === mode.id ? '#1D7DCC' : '#7F94A8')
        }
        .layoutWeight(1)
        .height(58)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.activeModeId === mode.id ? '#F2FFFFFF' : '#B8FFFFFF')
        .border({ width: 1, color: this.activeModeId === mode.id ? '#A7D8F8' : '#DCEBF5' })
        .borderRadius(18)
        .shadow({ radius: this.activeModeId === mode.id ? 12 : 0, color: '#146BA6D8', offsetY: 4 })
        .onClick(() => {
          if (!this.running) {
            this.activeModeId = mode.id;
            this.phase = '准备';
            this.phaseRemaining = mode.inhaleSeconds;
            this.round = 1;
            this.breathProgress = 0;
          } else {
            this.showToast('训练进行中，结束后可以切换呼吸模式。');
          }
        })
      }, (mode: BreathingMode) => {
        return mode.id;
      })
    }
    .width('100%')
  }

  @Builder
  BreathSupportCards() {
    Row({ space: 8 }) {
      this.PhasePill('吸气', this.selectedMode().inhaleSeconds.toString() + ' 秒', this.phase === '吸气')
      this.PhasePill('屏息', this.selectedMode().holdSeconds.toString() + ' 秒', this.phase === '屏息')
      this.PhasePill('呼气', this.selectedMode().exhaleSeconds.toString() + ' 秒', this.phase === '呼气')
    }
    .width('100%')
  }

  @Builder
  PhasePill(title: string, duration: string, active: boolean) {
    Column({ space: 3 }) {
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(active ? '#143B68' : '#5E7893')
      Text(duration)
        .fontSize(10)
        .fontColor(active ? '#1D7DCC' : '#7F94A8')
    }
    .layoutWeight(1)
    .height(56)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(active ? '#F2FFFFFF' : '#9EFFFFFF')
    .border({ width: 1, color: active ? '#A7D8F8' : '#DCEBF5' })
    .borderRadius(18)
    .scale({ x: active ? 1.02 : 1, y: active ? 1.02 : 1 })
    .animation({ duration: 220, curve: Curve.Friction })
  }

  @Builder
  TrainingRecordPanel() {
    Column({ space: 8 }) {
      Row() {
        Text('训练记录')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#143B68')
        Blank()
        Text('已完成 ' + this.records.length.toString() + ' 次')
          .fontSize(11)
          .fontColor('#5E7893')
      }
      .width('100%')

      if (this.records.length === 0) {
        Text('还没有完成过放松训练，试试 4-7-8 呼吸法开始。')
          .width('100%')
          .padding({ top: 22, bottom: 22 })
          .textAlign(TextAlign.Center)
          .fontSize(13)
          .fontColor('#5E7893')
      } else {
        ForEach(this.records, (item: TrainingRecord) => {
          Row({ space: 8 }) {
            Column({ space: 3 }) {
              Text(this.typeName(item.type))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#143B68')
              if (this.editingRecordId === item.id) {
                Row({ space: 6 }) {
                  TextInput({ text: this.editingDurationText })
                    .width(76)
                    .height(34)
                    .fontSize(11)
                    .type(InputType.Number)
                    .backgroundColor('#F6FFFFFF')
                    .borderRadius(10)
                    .onChange((value: string) => {
                      this.editingDurationText = value;
                    })
                  Text('分钟')
                    .fontSize(10)
                    .fontColor('#5E7893')
                }
              } else {
                Text(Math.max(1, Math.round(item.duration / 60)).toString() + ' 分钟 · ' +
                item.date.substring(0, 10))
                  .fontSize(11)
                  .fontColor('#6A829A')
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Button(this.editingRecordId === item.id ? '保存' : '编辑')
              .height(36)
              .fontSize(11)
              .fontColor('#1D7DCC')
              .backgroundColor('#DDF2FF')
              .onClick(() => {
                if (this.editingRecordId === item.id) {
                  this.saveRecordEdit(item);
                } else {
                  this.startEditRecord(item);
                }
              })
            Button('删除')
              .height(36)
              .fontSize(11)
              .fontColor(AppConstants.COLOR_DANGER)
              .backgroundColor('#FFFFEEEE')
              .onClick(() => {
                this.confirmDelete(item);
              })
          }
          .width('100%')
          .padding({ top: 9, bottom: 9 })
          .border({ width: { bottom: 1 }, color: '#DCEBF5' })
        }, (item: TrainingRecord) => {
          return item.id === undefined ? item.date : item.id.toString();
        })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#CCFFFFFF')
    .border({ width: 1, color: '#DCEBF5' })
    .borderRadius(AppConstants.RADIUS_CARD)
  }
}
