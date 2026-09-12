import {
  AppConstants,
  DailyQuote,
  ThoughtChallenge
} from '../common/DataModels';
import { PageHeader } from '../components/PageHeader';
import { MemePopup } from '../common/MemePopup';
import { DatabaseService } from '../services/DatabaseService';
import { HapticService } from '../services/HapticService';
import { MemeService } from '../services/MemeService';

@Entry
@Component
struct GamePage {
  @State viewportHeight: number = 760;
  @State viewportWidth: number = 390;
  @State pageMode: number = 0;
  @State quotes: DailyQuote[] = [];
  @State showCardDeck: boolean = false;
  @State activeCardIndex: number = 0;
  @State activeCardRevealed: boolean = false;
  @State deckScale: number = 0.84;
  @State deckOpacity: number = 0;
  @State cardScaleX: number = 1;
  @State challengeRecords: ThoughtChallenge[] = [];
  @State challengeOpen: boolean = false;
  @State challengeRound: number = 0;
  @State negativeThought: string = '';
  @State challengeAnswer: string = '';
  @State challengeAnswers: string[] = [];
  @State coachQuestion: string = '写下一个此刻最困扰你的负面想法，我们从证据开始梳理。';
  @State finalThought: string = '';
  @State loading: boolean = false;
  @State showMeme: boolean = false;
  @State memeMessage: string = '';
  @State editingChallengeId: number = -1;
  @State editingChallengeText: string = '';
  @State revealedCards: boolean[] = [false, false, false, false, false, false];
  @State pressedCardIndex: number = -1;
  private savingCardIds: number[] = [];
  private flipTimers: number[] = [];
  private deckRecordedIndices: number[] = [];
  private deckSavingIndices: number[] = [];
  private pageScroller: Scroller = new Scroller();

  private async enterFlipPage(): Promise<void> {
    if (this.loading) { return; }
    if (this.quotes.length < 6) { await this.resetFlipGrid(); }
    if (this.quotes.length >= 6) { this.pageMode = 1; }
  }

  private enterGrowthPage(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/EvolutionTreePage' }).catch(() => {
      this.showToast('思维进化树暂时没有打开，再试一次？');
    });
  }

  private openCognitivePage(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CognitiveWorkshopPage' }).catch(() => {
      this.showToast('认知重构工坊暂时没有打开，再试一次？');
    });
  }

  aboutToAppear(): void {
    this.loadData();
  }

  aboutToDisappear(): void {
    this.clearFlipTimers();
  }

  private async loadData(): Promise<void> {
    try { this.challengeRecords = await DatabaseService.getAllThoughtChallenges(); }
    catch (reason) { this.showToast('记录暂时没有加载完整。'); }
  }

  private revealedCount(): number {
    let count: number = 0;
    for (let index: number = 0; index < this.revealedCards.length; index++) {
      if (this.revealedCards[index]) {
        count++;
      }
    }
    return count;
  }

  private allCardsRevealed(): boolean {
    return this.revealedCount() >= 6;
  }

  private async revealGridCard(index: number): Promise<void> {
    if (this.loading || this.quotes.length < 6 || this.savingCardIds.indexOf(index) >= 0) { return; }
    if (this.revealedCards[index]) {
      this.getUIContext().getPromptAction().showDialog({ title: this.quotes[index].category,
        message: this.quotes[index].content, buttons: [{ text: '收好这句话', color: AppConstants.COLOR_PRIMARY }] });
      return;
    }
    this.savingCardIds.push(index);
    try {
      let saved: boolean = true;
      try {
        await DatabaseService.addCardDraw(this.quotes[index]);
      } catch (reason) {
        // 翻牌本身不依赖记录服务，离线时仍允许继续体验。
        saved = false;
      }
      const next: boolean[] = this.revealedCards.slice(); next[index] = true; this.revealedCards = next;
      HapticService.light();
      if (this.allCardsRevealed()) { HapticService.confirm(); }
      if (!saved) { this.showToast('已翻开，记录服务暂时不可用。'); }
    } finally {
      this.savingCardIds = this.savingCardIds.filter((item: number) => item !== index);
    }
  }

  private async resetFlipGrid(): Promise<void> {
    if (this.loading || this.savingCardIds.length > 0) { return; }
    this.loading = true;
    try {
      const next: DailyQuote[] = await DatabaseService.drawQuoteBatch(this.quotes);
      this.quotes = next; this.revealedCards = [false, false, false, false, false, false]; this.pressedCardIndex = -1;
    } catch (reason) {
      // 数据库抽卡失败时仍提供本地卡片，避免整页被阻塞。
      this.quotes = this.fallbackQuotes();
      this.revealedCards = [false, false, false, false, false, false];
      this.pressedCardIndex = -1;
      this.showToast('已切换到本地卡片，可以继续翻牌。');
    }
    finally { this.loading = false; }
  }

  private fallbackQuotes(): DailyQuote[] {
    const result: DailyQuote[] = [];
    for (let index: number = 0; index < 6; index++) {
      result.push({
        content: AppConstants.QUOTE_SEEDS[index].content,
        category: AppConstants.QUOTE_SEEDS[index].category,
        used: false
      });
    }
    return result;
  }

  private openCardDeck(): void {
    if (this.quotes.length < 6) {
      this.showToast('卡片正在准备，请稍后再试。');
      return;
    }
    this.clearFlipTimers();
    HapticService.confirm();
    this.activeCardIndex = 0;
    this.activeCardRevealed = false;
    this.cardScaleX = 1;
    this.deckScale = 0.84;
    this.deckOpacity = 0;
    this.showCardDeck = true;
    this.deckRecordedIndices = [];
    this.deckSavingIndices = [];
    const timerId: number = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 260, curve: Curve.Friction }, () => {
        this.deckScale = 1;
        this.deckOpacity = 1;
      });
    }, 30);
    this.flipTimers.push(timerId);
  }

  private revealActiveCard(): void {
    if (this.activeCardRevealed || !this.showCardDeck) {
      return;
    }
    HapticService.light();
    this.getUIContext().animateTo({ duration: 140, curve: Curve.EaseIn }, () => {
      this.cardScaleX = 0.02;
    });
    const timerId: number = setTimeout(() => {
      this.activeCardRevealed = true;
      this.recordDeckCard(this.activeCardIndex);
      this.getUIContext().animateTo({ duration: 190, curve: Curve.EaseOut }, () => {
        this.cardScaleX = 1;
      });
    }, 140);
    this.flipTimers.push(timerId);
  }

  private advanceCard(): void {
    if (!this.activeCardRevealed) {
      this.revealActiveCard();
      return;
    }
    if (this.activeCardIndex >= 5) {
      this.finishCardDeck();
      return;
    }
    this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseIn }, () => {
      this.deckScale = 0.86;
      this.deckOpacity = 0;
    });
    const timerId: number = setTimeout(() => {
      this.activeCardIndex++;
      this.activeCardRevealed = false;
      this.cardScaleX = 1;
      this.getUIContext().animateTo({ duration: 240, curve: Curve.Friction }, () => {
        this.deckScale = 1;
        this.deckOpacity = 1;
      });
    }, 160);
    this.flipTimers.push(timerId);
  }

  private closeCardDeck(): void {
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseIn }, () => {
      this.deckScale = 0.9;
      this.deckOpacity = 0;
    });
    const timerId: number = setTimeout(() => {
      this.showCardDeck = false;
    }, 180);
    this.flipTimers.push(timerId);
  }

  private async recordDeckCard(index: number): Promise<void> {
    if (index < 0 || index >= this.quotes.length || this.deckRecordedIndices.indexOf(index) >= 0 ||
      this.deckSavingIndices.indexOf(index) >= 0) {
      return;
    }
    this.deckSavingIndices.push(index);
    try {
      await DatabaseService.addCardDraw(this.quotes[index]);
      this.deckRecordedIndices.push(index);
    } catch (reason) {
      this.showToast('卡片已翻开，但成长记录暂时没有同步。');
    } finally {
      this.deckSavingIndices = this.deckSavingIndices.filter((item: number) => item !== index);
    }
  }

  private finishCardDeck(): void {
    // 最后一张翻开后再次兜底写入，避免动画或快速点击漏掉记录。
    for (let index: number = 0; index < 6; index++) {
      this.recordDeckCard(index);
    }
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseIn }, () => {
      this.deckScale = 0.9;
      this.deckOpacity = 0;
    });
    const timerId: number = setTimeout(() => {
      this.showCardDeck = false;
      this.showTip();
    }, 180);
    this.flipTimers.push(timerId);
  }

  private clearFlipTimers(): void {
    for (let index: number = 0; index < this.flipTimers.length; index++) {
      clearTimeout(this.flipTimers[index]);
    }
    this.flipTimers = [];
  }

  private showTip(): void {
    this.getUIContext().getPromptAction().showDialog({
      title: '考试技巧卡',
      message: '把“我肯定不行”翻过来：我有什么证据证明不行？又有什么证据证明可以？',
      buttons: [
        { text: '收下技巧', color: AppConstants.COLOR_PRIMARY }
      ]
    }).then(() => {
      this.showCompletionMeme('game_cards', '不错嘛！把担忧翻过来，也是一种实力。');
    });
  }

  private async showCompletionMeme(trigger: string, message: string): Promise<void> {
    if (await MemeService.shouldShow(trigger)) {
      this.memeMessage = message;
      this.showMeme = true;
    }
  }

  private resetCards(): void {
    this.clearFlipTimers();
    this.showCardDeck = false;
    this.activeCardIndex = 0;
    this.activeCardRevealed = false;
    this.deckScale = 0.84;
    this.deckOpacity = 0;
    this.cardScaleX = 1;
    this.openCardDeck();
  }

  private startChallenge(): void {
    if (this.negativeThought.trim().length === 0) {
      this.showToast('先写下一句最困扰你的想法。');
      return;
    }
    this.challengeRound = 1;
    this.challengeAnswers = [];
    this.coachQuestion = '有什么事实支持它？又有什么事实不支持它？';
    this.challengeAnswer = '';
  }

  private async submitChallenge(): Promise<void> {
    if (this.challengeAnswer.trim().length === 0 || this.loading) {
      return;
    }
    const submittedAnswer: string = this.challengeAnswer.trim();
    const updatedAnswers: string[] = this.challengeAnswers.slice();
    updatedAnswers.push(submittedAnswer);
    this.challengeAnswers = updatedAnswers;
    if (this.challengeRound < 3) {
      this.challengeRound++;
      this.coachQuestion = this.challengeRound === 2 ?
        '如果朋友这样想，你会怎么对他说？' :
        '把它改成一句更公平、更能行动的话。';
      this.challengeAnswer = '';
      return;
    }
    this.loading = true;
    try {
      this.finalThought = submittedAnswer;
      const item: ThoughtChallenge = {
        negativeThought: this.negativeThought.trim(),
        alternativeThought: this.finalThought,
        distortionType: this.detectDistortion(this.negativeThought),
        createdAt: new Date().toISOString()
      };
      await DatabaseService.addThoughtChallenge(item);
      await this.loadData();
      this.challengeRound = 4;
      this.showCompletionMeme('game_challenge', '你又成长了一次，平衡思维正在变成能力。');
      this.showToast('平衡思维已保存。');
    } catch (reason) {
      this.showToast('这次没有保存成功，你的回答还保留着。');
    } finally {
      this.loading = false;
    }
  }

  private detectDistortion(text: string): string {
    if (text.includes('一定') || text.includes('完了') || text.includes('最差')) {
      return '灾难化';
    }
    if (text.includes('永远') || text.includes('每次') || text.includes('从来')) {
      return '过度概括';
    }
    if (text.includes('必须') || text.includes('要么')) {
      return '非黑即白';
    }
    return '自动化负面想法';
  }

  private resetChallenge(): void {
    this.challengeRound = 0;
    this.negativeThought = '';
    this.challengeAnswer = '';
    this.challengeAnswers = [];
    this.finalThought = '';
    this.coachQuestion = '写下一个此刻最困扰你的负面想法，我们从证据开始梳理。';
  }

  private growthLevel(): number {
    return Math.min(3, this.challengeRecords.length);
  }

  private showEvolutionGuide(): void {
    this.getUIContext().getPromptAction().showDialog({
      title: '思维进化树怎么成长',
      message: '在上方“认知重构工坊”完成一次三轮挑战，就会保存一条平衡思维，并点亮一个成长阶段。完成 1 次萌芽、2 次生长、3 次开花；记录可以继续编辑或删除。',
      buttons: [
        { text: '去做一次挑战', color: AppConstants.COLOR_PRIMARY },
        { text: '知道了', color: AppConstants.COLOR_TEXT_SECONDARY }
      ]
    }).then((result) => {
      if (result.index === 0) {
        this.pageScroller.scrollTo({
          xOffset: 0,
          yOffset: 250,
          animation: { duration: 420, curve: Curve.EaseOut }
        });
      }
    });
  }

  private confirmBack(): void {
    if (this.pageMode !== 0) {
      if (this.challengeRound > 0 && this.challengeRound < 4) {
        this.getUIContext().getPromptAction().showDialog({
          title: '挑战还没完成',
          message: '现在退出会丢失本轮回答，确定要退出吗？',
          buttons: [
            { text: '继续挑战', color: AppConstants.COLOR_PRIMARY },
            { text: '退出', color: AppConstants.COLOR_DANGER }
          ]
        }).then((result) => {
          if (result.index === 1) {
            this.pageMode = 0;
          }
        });
      } else {
        this.pageMode = 0;
      }
      return;
    }
    if (this.challengeRound > 0 && this.challengeRound < 4) {
      this.getUIContext().getPromptAction().showDialog({
        title: '挑战还没完成',
        message: '现在退出会丢失本轮回答，确定要退出吗？',
        buttons: [
          { text: '继续挑战', color: AppConstants.COLOR_PRIMARY },
          { text: '退出', color: AppConstants.COLOR_DANGER }
        ]
      }).then((result) => {
        if (result.index === 1) {
          this.getUIContext().getRouter().back();
        }
      });
      return;
    }
    this.getUIContext().getRouter().back();
  }

  private confirmDelete(item: ThoughtChallenge): void {
    if (item.id === undefined) {
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: '删除成长记录',
      message: '这条思维进化记录删除后无法恢复，确定吗？',
      buttons: [
        { text: '保留', color: AppConstants.COLOR_TEXT_SECONDARY },
        { text: '删除', color: AppConstants.COLOR_DANGER }
      ]
    }).then((result) => {
      if (result.index === 1 && item.id !== undefined) {
        this.deleteChallenge(item.id);
      }
    });
  }

  private startEditChallenge(item: ThoughtChallenge): void {
    if (item.id === undefined) {
      return;
    }
    this.editingChallengeId = item.id;
    this.editingChallengeText = item.alternativeThought;
  }

  private async saveChallengeEdit(item: ThoughtChallenge): Promise<void> {
    if (item.id === undefined || this.editingChallengeText.trim().length === 0) {
      this.showToast('平衡思维不能为空。');
      return;
    }
    item.alternativeThought = this.editingChallengeText.trim();
    try {
      await DatabaseService.updateThoughtChallenge(item);
      this.editingChallengeId = -1;
      this.editingChallengeText = '';
      await this.loadData();
      this.showToast('平衡思维已更新。');
    } catch (reason) {
      this.showToast('刚才没有保存成功，内容还为你保留着。');
    }
  }

  private async deleteChallenge(id: number): Promise<void> {
    try {
      await DatabaseService.deleteThoughtChallenge(id);
      await this.loadData();
      this.showToast('成长记录已删除。');
    } catch (reason) {
      this.showToast('刚才没有删除成功，再试一次？');
    }
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
          colors: [['#DDF0FF', 0.0], ['#F2FAFF', 0.42], ['#DFF2FF', 1.0]]
        })

      Image($rawfile('kxq_breath_lake_scene.png'))
        .width('100%')
        .height(430)
        .objectFit(ImageFit.Cover)
        .opacity(0.58)
        .align(Alignment.Top)

      Image($rawfile('kxq_design_cloud_decor.png'))
        .width('125%')
        .height(240)
        .objectFit(ImageFit.Contain)
        .opacity(0.28)
        .margin({ top: 58 })

      // Keep the scrollable content and the home navigation in one vertical layout.
      // This gives the navigation a stable bottom slot on every device height.
      Column() {
        Scroll(this.pageScroller) {
          if (this.pageMode === 0) {
            this.GameHomePage()
          } else if (this.pageMode === 1) {
            this.FlipPage()
          } else {
            this.GrowthPage()
          }
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .scrollable(this.pageMode === 0 || this.pageMode === 1 ? ScrollDirection.None : ScrollDirection.Vertical)


      }
      .width('100%')
      .height('100%')

      if (this.showMeme) {
        MemePopup({
          visible: $showMeme,
          asset: 'daily_1',
          message: this.memeMessage
        })
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_old: Area, area: Area) => {
      this.viewportHeight = Number(area.height); this.viewportWidth = Number(area.width);
    })
  }

  @Builder
  GameHomePage() {
    Column({ space: 12 }) {
      PageHeader({ title: '心晴游戏坊' })
      this.GameHomeCard(
        '今日翻牌',
        '翻开一张小卡片\n看看今天的话',
        $rawfile('kxq_ref_game_flip_cards.png'),
        '#FFF7FCFF',
        '#2E73B9',
        () => {
          this.enterFlipPage();
        }
      )
      this.GameHomeCard(
        '认知重构工坊',
        '把担心慢慢理清',
        $rawfile('kxq_ref_game_cognitive_note.png'),
        '#FFF9FCF3',
        '#306D62',
        () => {
          this.openCognitivePage();
        }
      )

      this.GameHomeCard(
        '我的思维进化树',
        '看看你的思维成长',
        $rawfile('kxq_ui_cog_tree_full.png'),
        '#FFFDF5FF',
        '#527A55',
        () => {
          this.enterGrowthPage();
        }
      )
    }
    .width('100%')
    .height(this.viewportHeight)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  GameHomeCard(title: string, subtitle: string, art: Resource, background: string,
    titleColor: string, action: () => void) {
    Row() {
      Image(art)
        .width(this.viewportWidth < 360 ? 78 : 100)
        .height(100)
        .objectFit(ImageFit.Contain)
        .margin({ left: 8, right: 5 })
      Column({ space: 8 }) {
        Text(title)
          .width('100%')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(titleColor)
          .lineHeight(24)
          .maxLines(2)
        Text(subtitle)
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor(titleColor)
          .maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(36)
          .height(36)
          .borderRadius(24)
          .backgroundColor(titleColor)
          .opacity(0.75)
        Text('→')
          .fontSize(27)
          .fontColor('#FFFFFFFF')
      }
      .width(36)
      .height(36)
      .margin({ left: 5, right: 13 })
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ right: 0 })
    .backgroundColor(background)
    .border({ width: 1, color: '#D4E8F5' })
    .borderRadius(28)
    .shadow({ radius: 17, color: '#246EA522', offsetY: 8 })
    .onClick(action)
  }

  @Builder
  FlipPage() {
    Column({ space: 8 }) {
      this.GameTopBar()
      Row() {
        Text('给今天翻出一点好心情').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#235DA1').layoutWeight(1)
        Text(this.revealedCount().toString() + ' / 6').fontSize(13).fontColor('#4B80B7')
      }.width('100%').height(32)
      this.FlipGrid()
      Text('点击翻开；再次点击可读全文。整轮卡库用完前不重复。')
        .fontSize(11).fontColor('#4B80B7').width('100%').maxLines(2)
      Button(this.allCardsRevealed() ? '考试技巧卡已解锁 · 查看' : '翻开全部 6 张，解锁考试技巧卡')
        .width('100%').height(48).fontSize(13).backgroundColor('#E9F3FF').fontColor('#235DA1')
        .onClick(() => { if (this.allCardsRevealed()) { this.showTip(); } else { this.showToast('先翻开这一组卡片。'); } })
      this.GameFooterBar()
    }.width('100%').height(this.viewportHeight)
      .padding({ left: 16, right: 16, top: 8, bottom: 14 })
  }

  @Builder
  GrowthPage() {
    Column({ space: 18 }) {
      this.GrowthTopBar()
      Column({ space: 5 }) {
        Text('思维进化树')
          .fontSize(31)
          .fontWeight(FontWeight.Bold)
          .fontColor('#215C8E')
        Text('每一次重新看见自己，都会长出新的枝叶')
          .fontSize(15)
          .fontColor('#5C88A9')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 8, top: 6 })

      Stack({ alignContent: Alignment.Bottom }) {
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 180,
            colors: [['#EAF7FFFF', 0.0], ['#F9FFF4FF', 1.0]]
          })
          .border({ width: 1, color: '#D4EAF0' })
          .borderRadius(28)
        Image($rawfile('kxq_ui_cog_tree_full.png'))
          .width(218)
          .height(244)
          .objectFit(ImageFit.Contain)
          .opacity(this.growthLevel() > 0 ? 1 : 0.76)
          .margin({ bottom: 22 })
      }
      .width('100%')
      .height(286)
      .shadow({ radius: 16, color: '#246EA51A', offsetY: 7 })

      Row({ space: 8 }) {
        this.GrowthStage(1, '萌芽', '看见想法')
        this.GrowthStage(2, '生长', '找到证据')
        this.GrowthStage(3, '开花', '变得公平')
      }
      .width('100%')

      Row() {
        Column({ space: 4 }) {
          Text('认知重构工坊')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#245D78')
          Text('把一件担心，慢慢改写成可以行动的话')
            .fontSize(12)
            .fontColor('#6B8998')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button('开始挑战')
          .height(42)
          .fontSize(14)
          .fontColor('#FFFFFFFF')
          .backgroundColor('#3AA878')
          .borderRadius(21)
          .onClick(() => {
            this.openCognitivePage();
          })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#F7FFF7FF')
      .border({ width: 1, color: '#D6EFDA' })
      .borderRadius(22)

      this.GrowthRecords()
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 16, bottom: 28 })
  }

  @Builder
  GrowthTopBar() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Text('‹')
          .fontSize(30)
          .fontColor('#286AA0')
      }
      .width(52)
      .height(52)
      .backgroundColor('#DDF3FFFF')
      .onClick(() => {
        this.confirmBack();
      })
      Text('游戏坊')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A427A')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Button('说明')
        .height(40)
        .fontSize(13)
        .fontColor('#286AA0')
        .backgroundColor('#DDF3FFFF')
        .borderRadius(20)
        .onClick(() => {
          this.showEvolutionGuide();
        })
    }
    .width('100%')
  }

  @Builder
  GrowthRecords() {
    Column({ space: 10 }) {
      Row() {
        Text('成长记录')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#245D78')
          .layoutWeight(1)
        Text(this.challengeRecords.length.toString() + ' 条')
          .fontSize(13)
          .fontColor('#6B8998')
      }
      if (this.challengeRecords.length === 0) {
        Text('完成一次挑战后，这里会留下你的平衡思维。')
          .width('100%')
          .fontSize(13)
          .fontColor('#6B8998')
          .padding({ top: 8, bottom: 8 })
      } else {
        ForEach(this.challengeRecords.slice(0, 3), (item: ThoughtChallenge) => {
          Column({ space: 5 }) {
            Text(item.alternativeThought)
              .width('100%')
              .fontSize(14)
              .fontColor('#245D78')
              .maxLines(2)
            Text('来自：' + item.negativeThought)
              .width('100%')
              .fontSize(11)
              .fontColor('#86A0AD')
              .maxLines(1)
          }
          .width('100%')
          .padding(12)
          .backgroundColor('#F5FBFFFF')
          .borderRadius(14)
        }, (item: ThoughtChallenge) => {
          return item.id === undefined ? item.createdAt : item.id.toString();
        })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#F9FFFFFF')
    .border({ width: 1, color: '#DDEDF2' })
    .borderRadius(22)
  }

  @Builder
  GameTopBar() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Image($rawfile('back_arrow.svg')).width(24).height(24)
      }
      .width(44).height(44).accessibilityText('返回')
      .backgroundColor('#DBF4FFFF')
      .onClick(() => {
        this.confirmBack();
      })

      Text('今日翻牌')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A427A')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Button() {
        Row({ space: 6 }) {
          Text('?')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2865A8')
          Text('规则')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2865A8')
        }
        .justifyContent(FlexAlign.Center)
      }
      .width(72)
      .height(44)
      .backgroundColor('#DDF7FFFF')
      .borderRadius(22)
      .onClick(() => {
        this.showTip();
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  GameTitleBlock() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text('翻开')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2A72BB')
        Text('6')
          .fontSize(42)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F4C24D')
        Text('张小卡片')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2A72BB')
      }
      .justifyContent(FlexAlign.Center)
      Text('看看今天的话')
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2A72BB')
      Row({ space: 8 }) {
        Text(this.revealedCount().toString() + ' / 6')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2A72BB')
        Text(this.allCardsRevealed() ? '已全部翻开' : '点击卡片开始翻开吧')
          .fontSize(14)
          .fontColor('#4B80B7')
      }
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 22, bottom: 4 })
  }

  @Builder
  FlipGrid() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        this.FlipCard(0)
        this.FlipCard(1)
        this.FlipCard(2)
      }
      .width('100%').layoutWeight(1)
      Row({ space: 10 }) {
        this.FlipCard(3)
        this.FlipCard(4)
        this.FlipCard(5)
      }
      .width('100%').layoutWeight(1)
    }
    .width('100%').layoutWeight(1)
  }

  @Builder
  FlipCard(index: number) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.revealedCards[index] && this.quotes.length > index) {
        Column({ space: 7 }) {
          Image($rawfile('kxq_game_success_cloud.png'))
            .width(30)
            .height(24)
            .objectFit(ImageFit.Contain)
          Text(this.quotes[index].category)
            .fontSize(11)
            .fontColor('#2A72BB')
            .maxLines(1)
          Text(this.quotes[index].content)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A427A')
            .textAlign(TextAlign.Center)
            .lineHeight(18)
            .maxLines(3)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .padding(8)
        .backgroundColor('#F6FBFF')
        .border({ width: 2, color: '#BBDFFF' })
        .borderRadius(22)
      } else {
        Image($rawfile('kxq_game_flip_card_back.png'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .borderRadius(22)
      }
    }
    .layoutWeight(1)
    .height('100%')
    .borderRadius(22)
    .shadow({ radius: 16, color: '#2A69A5D4', offsetY: 7 })
    .scale({
      x: this.pressedCardIndex === index ? 0.95 : 1,
      y: this.pressedCardIndex === index ? 0.95 : 1
    })
    .animation({ duration: 160, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedCardIndex = index;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedCardIndex = -1;
      }
    })
    .onClick(() => {
      this.revealGridCard(index);
    })
  }

  @Builder
  FlipGuide() {
    Row({ space: 8 }) {
      Text('✧')
        .fontSize(18)
        .fontColor('#3B7FC8')
      Text(this.allCardsRevealed() ? '全部翻开后获得考试技巧卡' : '点击卡片开始翻开吧')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#3B7FC8')
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  RewardCard() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 118,
          colors: [['#F6FBFF', 0.0], ['#EAF5FF', 1.0]]
        })
        .border({ width: 1, color: '#CDE7FF' })
        .borderRadius(24)
      Row() {
        Column({ space: 12 }) {
          Text('全部翻开后获得')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2F6FAE')
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor('#E8E5F9FF')
            .borderRadius(16)
          Text('考试技巧卡')
            .fontSize(29)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A427A')
          Text(this.allCardsRevealed() ?
            '今日技巧已解锁，可以收下这份提醒。' :
            '一份实用小贴士，助你更从容地面对考试')
            .fontSize(15)
            .fontColor('#4B80B7')
            .maxLines(2)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Image($rawfile('kxq_game_reward_card_art.png'))
          .width(142)
          .height(128)
          .objectFit(ImageFit.Contain)
          .opacity(this.allCardsRevealed() ? 1 : 0.76)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 18, right: 14, top: 18, bottom: 18 })
    }
    .width('100%')
    .height(178)
    .shadow({ radius: 16, color: '#1A69A5D4', offsetY: 7 })
    .onClick(() => {
      if (this.allCardsRevealed()) {
        this.showTip();
      } else {
        this.showToast('先翻开六张小卡片。');
      }
    })
  }

  @Builder
  GameFooterBar() {
    Row({ space: 10 }) {
      Button('我的记录').layoutWeight(1).height(46).fontSize(14).fontColor('#235DA1').backgroundColor(Color.White)
        .onClick(() => { this.getUIContext().getRouter().pushUrl({ url: 'pages/GrowthRecordsPage', params: { filter: 1 } }).catch(() => {
          this.showToast('记录页暂时未打开。');
        }); })
      Button(this.loading ? '正在洗牌…' : '再翻一次').layoutWeight(1).height(46).fontSize(14)
        .enabled(!this.loading).backgroundColor('#2F80FF').fontColor(Color.White)
        .onClick(() => { this.resetFlipGrid(); })
    }.width('100%').height(46)
  }

  @Builder
  GameHeroBanner() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 126,
          colors: [['#EEF5FF', 0.0], ['#F1E8FF', 0.62], ['#E9F7FF', 1.0]]
        })
        .border({ width: 1, color: AppConstants.COLOR_CARD_BORDER })
        .borderRadius(28)
      Row() {
        Image($rawfile('kxq_ui_game_logo.png'))
          .width(218)
          .height(72)
          .objectFit(ImageFit.Contain)
        Blank()
        Image($rawfile('kxq_ui_game_wink_cloud.png'))
          .width(88)
          .height(82)
          .objectFit(ImageFit.Contain)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 14, right: 12, top: 10, bottom: 10 })
    }
    .width('100%')
    .height(112)
    .onClick(() => {
      this.openCardDeck();
    })
  }

  @Builder
  GrowthStage(level: number, title: string, detail: string) {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(38)
          .height(38)
          .borderRadius(19)
          .backgroundColor(this.growthLevel() >= level ? AppConstants.COLOR_PRIMARY : '#E6ECF4')
        Text(level.toString())
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.growthLevel() >= level ?
            AppConstants.COLOR_WHITE : AppConstants.COLOR_TEXT_TERTIARY)
      }
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.growthLevel() >= level ?
          AppConstants.COLOR_TEXT_PRIMARY : AppConstants.COLOR_TEXT_TERTIARY)
      Text(detail)
        .fontSize(9)
        .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
    }
    .layoutWeight(1)
    .padding({ top: 12, bottom: 10 })
    .backgroundColor(this.growthLevel() >= level ? '#14007DFF' : '#66F2F5F9')
    .border({
      width: 1,
      color: this.growthLevel() >= level ? '#33007DFF' : AppConstants.COLOR_DIVIDER
    })
    .borderRadius(16)
  }

  @Builder
  CardDeckOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#730A1730')
        .backgroundBlurStyle(BlurStyle.Thin)
        .onClick(() => {
          this.closeCardDeck();
        })

      Column({ space: 14 }) {
        Row() {
          Column({ space: 2 }) {
            Text('此刻的一句话')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
            Text('第 ' + (this.activeCardIndex + 1).toString() + ' 张，共 6 张')
              .fontSize(12)
              .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(17)
              .fontColor([AppConstants.COLOR_TEXT_SECONDARY])
          }
          .width(42)
          .height(42)
          .backgroundColor('#14000000')
          .onClick(() => {
            this.closeCardDeck();
          })
        }
        .width('100%')

        Row({ space: 7 }) {
          ForEach(this.quotes, (item: DailyQuote, index: number) => {
            Column()
              .layoutWeight(1)
              .height(5)
              .borderRadius(3)
              .backgroundColor(index <= this.activeCardIndex ?
                AppConstants.COLOR_PRIMARY : '#1A8899AA')
          }, (item: DailyQuote, index: number) => {
            return 'progress_' + index.toString();
          })
        }
        .width('100%')

        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(this.activeCardRevealed ? '#FFFDF8' : '#163C69')
            .border({ width: 1, color: this.activeCardRevealed ? '#33D8A64A' : '#668FCBFF' })
            .borderRadius(28)
            .shadow({ radius: 24, color: '#26001A38', offsetY: 10 })

          if (this.activeCardRevealed) {
            Column({ space: 18 }) {
              Text(this.quotes[this.activeCardIndex].category)
                .fontSize(12)
                .fontColor('#9B6818')
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor('#1AD8A64A')
                .borderRadius(14)
              Text(this.quotes[this.activeCardIndex].content)
                .fontSize(24)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
                .textAlign(TextAlign.Center)
                .lineHeight(36)
              Column()
                .width(38)
                .height(3)
                .borderRadius(2)
                .backgroundColor('#66D8A64A')
              Text('考心晴 · 今日心语')
                .fontSize(11)
                .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
            }
            .padding({ left: 24, right: 24 })
          } else {
            Column({ space: 16 }) {
              Image($rawfile('card_back.png'))
                .width(132)
                .height(132)
                .objectFit(ImageFit.Cover)
                .borderRadius(28)
              Text('轻触翻开')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppConstants.COLOR_WHITE)
              Text('一次只看一句，让注意力回到此刻')
                .fontSize(12)
                .fontColor('#BFFFFFFF')
            }
          }
        }
        .width('100%')
        .height(350)
        .scale({ x: this.cardScaleX, y: 1 })
        .onClick(() => {
          this.revealActiveCard();
        })

        Button(this.activeCardRevealed ?
          (this.activeCardIndex >= 5 ? '收下六句话' : '下一张') : '翻开这张')
          .width('100%')
          .height(50)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppConstants.COLOR_WHITE)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .borderRadius(18)
          .onClick(() => {
            this.advanceCard();
          })
      }
      .width('calc(100% - 48vp)')
      .padding(18)
      .backgroundColor('#F5FFFFFF')
      .backgroundBlurStyle(BlurStyle.Thick)
      .border({ width: 1, color: AppConstants.COLOR_CARD_BORDER })
      .borderRadius(30)
      .scale({ x: this.deckScale, y: this.deckScale })
      .opacity(this.deckOpacity)
    }
    .width('100%')
    .height('100%')
    .zIndex(120)
  }
}
