import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  Affirmation,
  AgentInsight,
  AppConstants,
  ChatMessage,
  DistortionItem,
  SafetyCheck
} from '../common/DataModels';
import { MemePopup } from '../common/MemePopup';
import { VoiceRecognitionService } from '../service/VoiceRecognitionService';
import { AffirmationAudioService } from '../services/AffirmationAudioService';
import { ApiService } from '../services/ApiService';
import { DatabaseService } from '../services/DatabaseService';
import { HapticService } from '../services/HapticService';
import { MemeService } from '../services/MemeService';
import { SafetyGuardService } from '../services/SafetyGuardService';
import { TinglanAgentService } from '../services/TinglanAgentService';

@Entry
@Component
export struct CognitivePage {
  @State messages: ChatMessage[] = [];
  @State inputText: string = '';
  @State placeholder: string = AppConstants.INPUT_PLACEHOLDERS[0];
  @State loading: boolean = false;
  @State loadingMessage: string = AppConstants.LOADING_MESSAGES[0];
  @State crisisDetected: boolean = false;
  @State listening: boolean = false;
  @State voiceStatus: string = '';
  @State affirmationExpanded: boolean = false;
  @State affirmations: Affirmation[] = [];
  @State affirmationRecording: boolean = false;
  @State affirmationTranscript: string = '';
  @State affirmationStatus: string = '';
  @State affirmationStartedAt: number = 0;
  @State editingAffirmationId: number = -1;
  @State editingAffirmationText: string = '';
  @State editingMessageId: number = -1;
  @State editingMessageText: string = '';
  @State showMeme: boolean = false;
  @State memeAsset: string = 'breakdown';
  @State memeMessage: string = '';
  @State memeFeatured: boolean = false;
  @State showCoachIntro: boolean = false;
  @State agentInsight: AgentInsight = TinglanAgentService.emptyInsight();
  @State safetyNotice: string = '';
  @State localMode: boolean = true;
  @State safetyDialogOpen: boolean = false;
  private messageScroller: Scroller = new Scroller();
  private chatVoice: VoiceRecognitionService = new VoiceRecognitionService();
  private affirmationVoice: VoiceRecognitionService = new VoiceRecognitionService();
  private affirmationPath: string = '';

  aboutToAppear(): void {
    const placeholderIndex: number = Math.floor(Math.random() * AppConstants.INPUT_PLACEHOLDERS.length);
    this.placeholder = AppConstants.INPUT_PLACEHOLDERS[placeholderIndex];
    this.loadData();
    ApiService.getApiKey().then((key: string) => { this.localMode = key.length === 0; });
    this.checkCoachFirstVisit();
    if (AppStorage.get<string>('expandSection') === 'affirmation') {
      this.affirmationExpanded = true;
      AppStorage.setOrCreate('expandSection', '');
    }
  }

  aboutToDisappear(): void {
    this.chatVoice.release();
    this.affirmationVoice.release();
  }

  private async loadData(): Promise<void> {
    try {
      const savedMessages: ChatMessage[] = await DatabaseService.getAllChatMessages();
      const validMessages: ChatMessage[] = [];
      let hasValidAssistant: boolean = false;
      for (let index: number = 0; index < savedMessages.length; index++) {
        const item: ChatMessage = savedMessages[index];
        const isBrokenAssistant: boolean =
          item.role === 'assistant' && item.content.trim().length <= 1;
        const hasInvalidRole: boolean = item.role !== 'user' && item.role !== 'assistant';
        if (isBrokenAssistant || hasInvalidRole) {
          if (item.id !== undefined) {
            await DatabaseService.deleteChatMessage(item.id);
          }
        } else {
          validMessages.push(item);
          if (item.role === 'assistant') {
            hasValidAssistant = true;
          }
        }
      }
      this.affirmations = await DatabaseService.getAllAffirmations();
      this.agentInsight = TinglanAgentService.analyzeMessages(validMessages);
      if (validMessages.length === 0) {
        const welcome: ChatMessage = {
          role: 'assistant',
          content: '你好呀，我是小晴。最近在准备什么考试？感觉怎么样？',
          timestamp: new Date().toISOString()
        };
        welcome.id = await DatabaseService.addChatMessage(welcome);
        this.messages = [welcome];
      } else {
        this.messages = validMessages;
        if (!hasValidAssistant) {
          const recoveredWelcome: ChatMessage = {
            role: 'assistant',
            content: '刚才的回复没有完整保存，我们重新开始。此刻最想聊哪一件事？',
            timestamp: new Date().toISOString()
          };
          recoveredWelcome.id = await DatabaseService.addChatMessage(recoveredWelcome);
          const recoveredMessages: ChatMessage[] = this.messages.slice();
          recoveredMessages.push(recoveredWelcome);
          this.messages = recoveredMessages;
        }
      }
      if ((AppStorage.get<boolean>('playLatestAffirmation') ?? false) && this.affirmations.length > 0) {
        AppStorage.setOrCreate('playLatestAffirmation', false);
        await this.playAffirmation(this.affirmations[0]);
      }
      this.scrollToBottom();
    } catch (reason) {
      if (this.messages.length === 0) {
        this.messages = [
          {
            role: 'assistant',
            content: '你好呀，我是小晴。最近在准备什么考试？感觉怎么样？',
            timestamp: new Date().toISOString()
          }
        ];
      }
      this.showToast('对话记录暂时没有加载出来。');
    }
  }

  private async checkCoachFirstVisit(): Promise<void> {
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const store: preferences.Preferences =
        await preferences.getPreferences(context, 'kaoxinqing_onboarding');
      const seenValue: preferences.ValueType = await store.get('coach_multi_agent_intro_v1', false);
      if (!(seenValue as boolean)) {
        this.showCoachIntro = true;
        await store.put('coach_multi_agent_intro_v1', true);
        await store.flush();
      }
    } catch (reason) {
      this.showCoachIntro = true;
    }
  }

  private async sendMessage(presetContent?: string): Promise<void> {
    const content: string = presetContent === undefined ?
      this.inputText.trim() : presetContent.trim();
    if (content.length === 0) {
      this.showToast('先写下一句想对小晴说的话。');
      return;
    }
    if (this.loading) {
      return;
    }
    const incoming: ChatMessage = { role: 'user', content: content };
    const safety: SafetyCheck = SafetyGuardService.checkConversation(this.messages.concat([incoming]));
    this.agentInsight = TinglanAgentService.analyzeText(content);
    this.safetyNotice = safety.riskLevel === 'support' ? safety.message : '';
    this.inputText = '';
    const userMessage: ChatMessage = {
      role: 'user',
      content: content,
      timestamp: new Date().toISOString()
    };
    try {
      userMessage.id = await DatabaseService.addChatMessage(userMessage);
    } catch (reason) {
      this.showToast('这条消息暂时没有保存，但仍可以继续对话。');
    }
    const nextMessages: ChatMessage[] = this.messages.slice();
    nextMessages.push(userMessage);
    this.messages = nextMessages;
    this.scrollToBottom();

    if (safety.shouldStopModel) {
      this.crisisDetected = true;
      this.safetyNotice = safety.message;
      this.appendAssistantMessage(safety.message);
      this.showSafetyDialog(safety);
      return;
    }

    this.crisisDetected = false;
    if (safety.riskLevel === 'support') { this.showSafetyDialog(safety); }
    if (presetContent === undefined && safety.riskLevel === 'normal') {
      await this.maybeShowTopicMeme(content);
    }
    this.loading = true;
    this.loadingMessage = AppConstants.LOADING_MESSAGES[
      Math.floor(Math.random() * AppConstants.LOADING_MESSAGES.length)
    ];
    try {
      const reply: string = await ApiService.cognitiveCoachRequest(this.messages);
      if (reply.trim().length >= 4) {
        this.appendAssistantMessage(reply.trim());
      } else {
        this.appendAssistantMessage(
          '我收到你的话了。我是AI助手，想先陪你把担心变得具体一点：最让你不安的结果是什么？'
        );
      }
    } catch (reason) {
      this.showToast('感觉信号不太好，检查一下网络连接？');
    } finally {
      this.loading = false;
    }
  }

  private showSafetyDialog(safety: SafetyCheck): void {
    if (this.safetyDialogOpen) { return; }
    this.showMeme = false;
    this.safetyDialogOpen = true;
    this.getUIContext().getPromptAction().showDialog({
      title: safety.title,
      message: safety.message,
      buttons: [{ text: '查看求助方式', color: AppConstants.COLOR_PRIMARY },
        { text: '继续说说', color: AppConstants.COLOR_TEXT_SECONDARY }]
    }).then((result) => {
      this.safetyDialogOpen = false;
      if (result.index === 0) { router.pushUrl({ url: 'pages/SupportPage' }).catch(() => {
        this.showToast('可直接拨打12356；有迫近危险请拨打120/110。');
      }); }
    }).catch(() => { this.safetyDialogOpen = false; });
  }

  private async maybeShowTopicMeme(content: string): Promise<void> {
    const topic: string = MemeService.matchTopic(content);
    if (topic.length === 0 || !await MemeService.shouldShow('topic_' + topic)) {
      return;
    }
    this.memeAsset = topic;
    this.memeFeatured = false;
    if (topic === 'songhao') {
      this.memeMessage = '数学老师也在给你肯定，先做会做的那一步。';
    } else if (topic === 'studycat') {
      this.memeMessage = '先别给结果下结论，总还有可以调整的空间。';
    } else {
      this.memeMessage = '先喝口冰茶，慢慢呼气，再一起梳理。';
    }
    this.showMeme = true;
  }

  private appendAssistantMessage(fullText: string): void {
    const normalizedText: string = fullText.trim();
    if (normalizedText.length < 2) {
      return;
    }
    const message: ChatMessage = {
      role: 'assistant',
      content: normalizedText,
      timestamp: new Date().toISOString()
    };
    const updated: ChatMessage[] = this.messages.slice();
    updated.push(message);
    this.messages = updated;
    this.scrollToBottom();
    this.persistAssistant(normalizedText);
  }

  private async persistAssistant(content: string): Promise<void> {
    const lastIndex: number = this.messages.length - 1;
    if (lastIndex < 0) {
      return;
    }
    try {
      const id: number = await DatabaseService.addChatMessage({
        role: 'assistant',
        content: content,
        timestamp: new Date().toISOString()
      });
      const updated: ChatMessage[] = this.messages.slice();
      updated[lastIndex].id = id;
      this.messages = updated;
    } catch (reason) {
      this.showToast('回复已经显示，但这次没有写入历史记录。');
    }
  }

  private scrollToBottom(): void {
    setTimeout(() => {
      this.messageScroller.scrollEdge(Edge.Bottom);
    }, 50);
  }

  private sendStarter(content: string, asset: string, message: string): void {
    if (this.loading) {
      return;
    }
    this.memeAsset = asset;
    this.memeMessage = message;
    this.memeFeatured = true;
    this.showMeme = true;
    this.sendMessage(content);
  }

  private async toggleChatVoice(): Promise<void> {
    if (this.listening) {
      await this.chatVoice.stop();
      this.listening = false;
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    const started: boolean = await this.chatVoice.start(
      context,
      (text: string, isFinal: boolean) => {
        this.inputText = text;
        if (isFinal) {
          this.listening = false;
          this.sendMessage();
        }
      },
      (status: string) => {
        this.voiceStatus = status;
        if (status.includes('完成') || status.includes('不可用') || status.includes('权限')) {
          this.listening = false;
        }
      }
    );
    this.listening = started;
    if (!started) {
      this.showToast('麦克风好像没声音，检查一下权限？');
    }
  }

  private showDistortions(): void {
    let detail: string = '';
    for (let index: number = 0; index < AppConstants.DISTORTION_TYPES.length; index++) {
      const item: DistortionItem = AppConstants.DISTORTION_TYPES[index];
      detail += item.name + '：' + item.description;
      if (index < AppConstants.DISTORTION_TYPES.length - 1) {
        detail += '\n\n';
      }
    }
    this.getUIContext().getPromptAction().showDialog({
      title: '常见认知扭曲',
      message: detail,
      buttons: [
        { text: '知道了', color: AppConstants.COLOR_PRIMARY }
      ]
    });
  }

  private async toggleAffirmationRecording(): Promise<void> {
    HapticService.confirm();
    if (this.affirmationRecording) {
      await this.affirmationVoice.stop();
      this.affirmationRecording = false;
      this.affirmationStatus = '录音已停止，可以预览文字并保存';
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.affirmationPath = context.filesDir + '/affirmation_' + Date.now().toString() + '.pcm';
    this.affirmationTranscript = '';
    this.affirmationStartedAt = Date.now();
    const started: boolean = await this.affirmationVoice.start(
      context,
      (text: string, isFinal: boolean) => {
        this.affirmationTranscript = text;
        if (isFinal) {
          this.affirmationRecording = false;
          this.affirmationStatus = '识别完成，可以保存';
        }
      },
      (status: string) => {
        this.affirmationStatus = status;
        if (status.includes('不可用') || status.includes('权限')) {
          this.affirmationRecording = false;
        }
      },
      this.affirmationPath
    );
    this.affirmationRecording = started;
    if (!started) {
      this.showToast('麦克风好像没声音，检查一下权限？');
    }
  }

  private async saveAffirmation(): Promise<void> {
    const original: string = this.affirmationTranscript.trim();
    if (original.length === 0 || this.affirmationPath.length === 0) {
      this.showToast('先录一段想对自己说的话吧。');
      return;
    }
    this.affirmationStatus = '正在把鼓励语变得更有力量……';
    let polished: string = original;
    try {
      const aiText: string = await ApiService.polishAffirmation(original);
      if (!aiText.includes('断线')) {
        polished = aiText;
      }
      const duration: number = Math.max(1, Math.round((Date.now() - this.affirmationStartedAt) / 1000));
      await DatabaseService.addAffirmation({
        text: polished,
        originalText: original,
        filePath: this.affirmationPath,
        duration: duration,
        createdAt: new Date().toISOString()
      });
      this.affirmationTranscript = '';
      this.affirmationPath = '';
      this.affirmationStatus = '';
      this.affirmations = await DatabaseService.getAllAffirmations();
      this.showToast('鼓励语音已保存。');
    } catch (reason) {
      this.affirmationStatus = '刚才没有保存成功，录音内容还在';
      this.showToast('录音没有保存成功，再试一次？');
    }
  }

  private async playAffirmation(item: Affirmation): Promise<void> {
    if (item.filePath.length === 0) {
      this.showToast('这条记录没有可播放的音频文件。');
      return;
    }
    try {
      await AffirmationAudioService.play(item.filePath);
    } catch (reason) {
      this.showToast('这段录音暂时无法播放。');
    }
  }

  private startEditAffirmation(item: Affirmation): void {
    this.editingAffirmationId = item.id === undefined ? -1 : item.id;
    this.editingAffirmationText = item.text;
  }

  private async saveAffirmationEdit(item: Affirmation): Promise<void> {
    if (this.editingAffirmationText.trim().length === 0 || item.id === undefined) {
      return;
    }
    item.text = this.editingAffirmationText.trim();
    try {
      await DatabaseService.updateAffirmation(item);
      this.editingAffirmationId = -1;
      this.editingAffirmationText = '';
      this.affirmations = await DatabaseService.getAllAffirmations();
      this.showToast('鼓励文字已更新。');
    } catch (reason) {
      this.showToast('文字没有更新成功，再试一次？');
    }
  }

  private confirmDeleteAffirmation(item: Affirmation): void {
    if (item.id === undefined) {
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: '删除鼓励录音',
      message: '删除后无法恢复这段录音，确定吗？',
      buttons: [
        { text: '保留', color: AppConstants.COLOR_TEXT_SECONDARY },
        { text: '删除', color: AppConstants.COLOR_DANGER }
      ]
    }).then((result) => {
      if (result.index === 1 && item.id !== undefined) {
        this.deleteAffirmation(item.id);
      }
    });
  }

  private async deleteAffirmation(id: number): Promise<void> {
    try {
      await DatabaseService.deleteAffirmation(id);
      this.affirmations = await DatabaseService.getAllAffirmations();
      this.showToast('鼓励录音已删除。');
    } catch (reason) {
      this.showToast('刚才没有删除成功，再试一次？');
    }
  }

  private startEditMessage(item: ChatMessage): void {
    if (item.id === undefined) {
      return;
    }
    this.editingMessageId = item.id;
    this.editingMessageText = item.content;
  }

  private async saveMessageEdit(item: ChatMessage): Promise<void> {
    const content: string = this.editingMessageText.trim();
    if (item.id === undefined || content.length === 0) {
      return;
    }
    item.content = content;
    try {
      await DatabaseService.updateChatMessage(item);
      this.editingMessageId = -1;
      this.editingMessageText = '';
      this.messages = await DatabaseService.getAllChatMessages();
      this.showToast('消息已更新。');
    } catch (reason) {
      this.showToast('消息没有更新成功，再试一次？');
    }
  }

  private confirmDeleteMessage(item: ChatMessage): void {
    if (item.id === undefined) {
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: '删除消息',
      message: '删除后无法恢复，确定删除这条消息吗？',
      buttons: [
        { text: '保留', color: AppConstants.COLOR_TEXT_SECONDARY },
        { text: '删除', color: AppConstants.COLOR_DANGER }
      ]
    }).then((result) => {
      if (result.index === 1 && item.id !== undefined) {
        this.deleteMessage(item.id);
      }
    });
  }

  private async deleteMessage(id: number): Promise<void> {
    try {
      await DatabaseService.deleteChatMessage(id);
      this.editingMessageId = -1;
      this.editingMessageText = '';
      this.messages = await DatabaseService.getAllChatMessages();
      if (this.messages.length === 0) {
        await this.loadData();
      }
      this.showToast('消息已删除。');
    } catch (reason) {
      this.showToast('消息没有删除成功，再试一次？');
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
          colors: [['#D9EEFF', 0.0], ['#F6FBFF', 0.55], ['#EAF4FF', 1.0]]
        })

      Image($rawfile('kxq_scene_day_lake_sail_wide.png'))
        .width('116%')
        .height(360)
        .objectFit(ImageFit.Cover)
        .opacity(0.22)
        .align(Alignment.Bottom)

      Image($rawfile('kxq_scene_cloud.png'))
        .width(240)
        .height(120)
        .objectFit(ImageFit.Contain)
        .opacity(0.38)
        .align(Alignment.TopEnd)
        .margin({ top: 40, right: -46 })

      Column() {
      Row({ space: 10 }) {
        Button({ type: ButtonType.Circle }) {
          Image($rawfile('back_arrow.svg')).width(24).height(24)
      }
        .width(44).height(44).accessibilityText('返回')
        .backgroundColor('#F4FFFFFF')
        .border({ width: 1, color: '#DAE9F8' })
        .shadow({ radius: 12, color: '#166BA6D8', offsetY: 4 })
        .onClick(() => {
          HapticService.light();
          router.back();
        })

        Image($rawfile('kxq_ui_chat_wave_mascot.png'))
          .objectFit(ImageFit.Contain)
          .borderRadius(21)
          .onClick(() => {
            this.showCoachIntro = true;
          })
        .width(42)
        .height(42)
        Column({ space: 2 }) {
          Text('听澜心语')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
          Text(this.localMode ? '本地陪伴模式 · 未连接在线模型' : 'AI 陪伴 · 不能替代专业帮助')
            .fontSize(11)
            .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.eye'))
            .fontSize(20)
            .fontColor([AppConstants.COLOR_PRIMARY])
        }
        .width(42)
        .height(42)
        .backgroundColor('#14007DFF')
        .onClick(() => {
          this.showDistortions();
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })

      this.ChatCompanionPanel()
      this.AgentInsightPanel()

      List({ space: 10, scroller: this.messageScroller }) {
        ForEach(this.messages, (item: ChatMessage) => {
          ListItem() {
            Row() {
              Column({ space: 5 }) {
                Text(item.role === 'user' ? '我' : '小晴')
                  .width('100%')
                  .fontSize(10)
                  .fontColor(item.role === 'user' ?
                    '#BFFFFFFF' : AppConstants.COLOR_TEXT_TERTIARY)
                if (this.editingMessageId === item.id) {
                  TextArea({ text: this.editingMessageText })
                    .width('100%')
                    .height(72)
                    .fontSize(14)
                    .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
                    .backgroundColor('#99FFFFFF')
                    .borderRadius(10)
                    .onChange((value: string) => {
                      this.editingMessageText = value;
                    })
                } else {
                  Text(item.content)
                    .width('100%')
                    .fontSize(14)
                    .fontColor(item.role === 'user' ?
                      AppConstants.COLOR_WHITE : AppConstants.COLOR_TEXT_PRIMARY)
                }
                if (item.id !== undefined) {
                  Row({ space: 12 }) {
                    Text(this.editingMessageId === item.id ? '保存' : '编辑')
                      .fontSize(10)
                      .fontColor(item.role === 'user' ?
                        '#D9FFFFFF' : AppConstants.COLOR_PRIMARY)
                      .onClick(() => {
                        if (this.editingMessageId === item.id) {
                          this.saveMessageEdit(item);
                        } else {
                          this.startEditMessage(item);
                        }
                      })
                    Text('删除')
                      .fontSize(10)
                      .fontColor(item.role === 'user' ?
                        '#D9FFFFFF' : AppConstants.COLOR_DANGER)
                      .onClick(() => {
                        this.confirmDeleteMessage(item);
                      })
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.End)
                }
              }
                .width(item.role === 'user' ? '76%' : '86%')
                .alignItems(HorizontalAlign.Start)
                .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .backgroundColor(item.role === 'user' ?
                  AppConstants.COLOR_PRIMARY : '#CFFFFFFF')
                .backgroundBlurStyle(BlurStyle.Thin)
                .borderRadius(item.role === 'user' ?
                  { topLeft: 16, topRight: 4, bottomLeft: 16, bottomRight: 16 } :
                  { topLeft: 4, topRight: 16, bottomLeft: 16, bottomRight: 16 })
            }
            .width('100%')
            .justifyContent(item.role === 'user' ? FlexAlign.End : FlexAlign.Start)
          }
        }, (item: ChatMessage, index: number) => {
          return item.id === undefined ? index.toString() : item.id.toString();
        })

        if (this.loading) {
          ListItem() {
            Row({ space: 8 }) {
              LoadingProgress()
                .width(18)
                .height(18)
                .color(AppConstants.COLOR_PRIMARY)
              Text(this.loadingMessage)
                .fontSize(13)
                .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
            }
            .padding(12)
            .backgroundColor('#99FFFFFF')
            .borderRadius(14)
          }
        }

        if (this.crisisDetected) {
          ListItem() {
            Column({ space: 8 }) {
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
                  .fontSize(20)
                  .fontColor([AppConstants.COLOR_DANGER])
                Text('请优先联系真实的人和专业支持')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppConstants.COLOR_DANGER)
              }
              .width('100%')
              Text('我不会把这段内容发送给AI。请联系信任的家人、老师或同学，并拨打心理援助热线。')
                .width('100%')
                .fontSize(13)
                .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
              Text(AppConstants.HOTLINE_NATIONAL + '  /  青少年服务台 ' + AppConstants.HOTLINE_YOUTH)
                .width('100%')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppConstants.COLOR_DANGER)
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#0FFF3B30')
            .border({ width: 1, color: '#66FF3B30' })
            .borderRadius(16)
          }
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      Column({ space: 8 }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.mic_sound'))
            .fontSize(19)
            .fontColor([AppConstants.COLOR_PRIMARY])
          Text('我的鼓励录音')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
            .layoutWeight(1)
          Text('已保存 ' + this.affirmations.length.toString() + ' 条')
            .fontSize(10)
            .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
          Text(this.affirmationExpanded ? '收起' : '展开')
            .fontSize(11)
            .fontColor(AppConstants.COLOR_PRIMARY)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#12007DFF')
            .borderRadius(10)
        }
        .width('100%')
        .height(42)
        .onClick(() => {
          animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
            this.affirmationExpanded = !this.affirmationExpanded;
          });
        })

        if (this.affirmationExpanded) {
          Column({ space: 10 }) {
            Row({ space: 10 }) {
              Button() {
                Row({ space: 6 }) {
                  SymbolGlyph($r('sys.symbol.mic_sound'))
                    .fontSize(18)
                    .fontColor([AppConstants.COLOR_WHITE])
                  Text(this.affirmationRecording ? '停止录音' : '开始录音')
                    .fontSize(13)
                    .fontColor(AppConstants.COLOR_WHITE)
                }
              }
              .layoutWeight(1)
              .height(44)
              .backgroundColor(this.affirmationRecording ?
                AppConstants.COLOR_DANGER : AppConstants.COLOR_PRIMARY)
              .onClick(() => {
                this.toggleAffirmationRecording();
              })
              Button('保存')
                .width(80)
                .height(44)
                .enabled(!this.affirmationRecording && this.affirmationTranscript.trim().length > 0)
                .fontColor(AppConstants.COLOR_PRIMARY)
                .backgroundColor('#14007DFF')
                .onClick(() => {
                  this.saveAffirmation();
                })
            }
            .width('100%')
            if (this.affirmationStatus.length > 0) {
              Text(this.affirmationStatus)
                .width('100%')
                .fontSize(11)
                .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
            }
            if (this.affirmationTranscript.length > 0) {
              Text(this.affirmationTranscript)
                .width('100%')
                .fontSize(13)
                .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
                .padding(10)
                .backgroundColor('#66FFFFFF')
                .borderRadius(12)
            }
            if (this.affirmations.length === 0) {
              Text('还没录过鼓励语音呢，试试录一段吧。')
                .width('100%')
                .padding({ top: 14, bottom: 14 })
                .textAlign(TextAlign.Center)
                .fontSize(12)
                .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
            } else {
              List({ space: 6 }) {
                ForEach(this.affirmations.slice(0, 4), (item: Affirmation, index: number) => {
                  ListItem() {
                    Column({ space: 7 }) {
                      if (this.editingAffirmationId === item.id) {
                        TextInput({ text: this.editingAffirmationText })
                          .width('100%')
                          .height(42)
                          .backgroundColor('#99FFFFFF')
                          .onChange((value: string) => {
                            this.editingAffirmationText = value;
                          })
                      } else {
                        Text(item.text)
                          .width('100%')
                          .fontSize(13)
                          .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
                          .maxLines(2)
                      }
                      Row({ space: 6 }) {
                        Text((index === 0 ? '最近录制 · ' : '') +
                        item.duration.toString() + ' 秒 · ' + item.createdAt.substring(0, 10))
                          .fontSize(10)
                          .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
                          .layoutWeight(1)
                        Button('播放')
                          .height(32)
                          .fontSize(10)
                          .fontColor(AppConstants.COLOR_PRIMARY)
                          .backgroundColor('#14007DFF')
                          .onClick(() => {
                            this.playAffirmation(item);
                          })
                        Button(this.editingAffirmationId === item.id ? '保存' : '编辑')
                          .height(32)
                          .fontSize(10)
                          .fontColor(AppConstants.COLOR_PRIMARY)
                          .backgroundColor('#14007DFF')
                          .onClick(() => {
                            if (this.editingAffirmationId === item.id) {
                              this.saveAffirmationEdit(item);
                            } else {
                              this.startEditAffirmation(item);
                            }
                          })
                        Button('删除')
                          .height(32)
                          .fontSize(10)
                          .fontColor(AppConstants.COLOR_DANGER)
                          .backgroundColor('#14FF3B30')
                          .onClick(() => {
                            this.confirmDeleteAffirmation(item);
                          })
                      }
                      .width('100%')
                    }
                    .width('100%')
                    .padding(10)
                    .backgroundColor('#66FFFFFF')
                    .borderRadius(12)
                  }
                }, (item: Affirmation) => {
                  return item.id === undefined ? item.createdAt : item.id.toString();
                })
              }
              .width('100%')
              .height(Math.min(228, this.affirmations.length * 76))
              .scrollBar(BarState.Off)
            }
          }
          .width('100%')
          .transition(TransitionEffect.OPACITY)
        }
      }
      .width('calc(100% - 32vp)')
      .padding({ left: 14, right: 14, bottom: this.affirmationExpanded ? 12 : 0 })
      .margin({ left: 16, right: 16, top: 6 })
      .backgroundColor('#99FFFFFF')
      .backgroundBlurStyle(BlurStyle.Thin)
      .border({ width: 1, color: AppConstants.COLOR_CARD_BORDER })
      .borderRadius(16)

      Row({ space: 8 }) {
        Button('我担心考砸')
          .height(32)
          .fontSize(11)
          .fontColor(AppConstants.COLOR_PRIMARY)
          .backgroundColor('#12007DFF')
          .onClick(() => {
            this.sendStarter(
              '我很担心这次考试会考砸。',
              'studycat',
              '先别替结果下结论，把最担心的部分说清楚。'
            );
          })
        Button('复习没进度')
          .height(32)
          .fontSize(11)
          .fontColor(AppConstants.COLOR_PRIMARY)
          .backgroundColor('#12007DFF')
          .onClick(() => {
            this.sendStarter(
              '我觉得复习进度不够，心里很着急。',
              'daily_3',
              '进度慢一点没关系，先完成眼前最小的一步。'
            );
          })
        Button('最近睡不好')
          .height(32)
          .fontSize(11)
          .fontColor(AppConstants.COLOR_PRIMARY)
          .backgroundColor('#12007DFF')
          .onClick(() => {
            this.sendStarter(
              '我最近因为考试睡不好。',
              'breakdown',
              '先把呼吸放慢，今晚不必一次解决所有担心。'
            );
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 7 })

      Row({ space: 8 }) {
        TextInput({
          placeholder: this.listening ? '正在聆听，请说话…' : this.placeholder,
          text: this.inputText
        })
          .layoutWeight(1)
          .height(46)
          .fontSize(14)
          .backgroundColor('#99FFFFFF')
          .borderRadius(23)
          .onChange((value: string) => {
            this.inputText = value;
          })
          .onSubmit(() => {
            this.sendMessage();
          })
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.mic_sound'))
            .fontSize(20)
            .fontColor([this.listening ? AppConstants.COLOR_WHITE : AppConstants.COLOR_PRIMARY])
        }
        .width(44)
        .height(44)
        .backgroundColor(this.listening ? AppConstants.COLOR_DANGER : '#14007DFF')
        .onClick(() => {
          this.toggleChatVoice();
        })
        Button('发送')
          .width(62)
          .height(44)
          .enabled(!this.loading)
          .fontSize(13)
          .fontColor(AppConstants.COLOR_WHITE)
          .backgroundColor(this.loading ? '#AAB4C2' : AppConstants.COLOR_PRIMARY)
          .onClick(() => {
            this.sendMessage();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 10 })
      .backgroundColor('#E8FFFFFF')
      .backgroundBlurStyle(BlurStyle.Thick)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#00FFFFFF')
      if (this.showCoachIntro) {
        this.CoachIntroOverlay()
      }
      if (this.showMeme) {
        MemePopup({
          visible: $showMeme,
          asset: this.memeAsset,
          message: this.memeMessage,
          featured: this.memeFeatured,
          displayDuration: this.memeFeatured ? 0 : 3000
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  AgentInsightPanel() {
    Column({ space: 10 }) {
      Row() {
        Text('四智能体协作状态')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
          .layoutWeight(1)
        Text(this.agentInsight.safetyLevel === 'normal' ? '日常陪伴' : '需要支持')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.agentInsight.safetyLevel === 'normal' ? '#20A85C' : AppConstants.COLOR_DANGER)
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor(this.agentInsight.safetyLevel === 'normal' ? '#E8F8EE' : '#FFF0EE')
          .borderRadius(12)
      }
      .width('100%')
      Row({ space: 6 }) {
        this.AgentChip('统筹', '统一回复')
        this.AgentChip('听澜', this.agentInsight.emotion)
        this.AgentChip('明镜', this.agentInsight.distortion)
        this.AgentChip('拾光', this.agentInsight.action)
      }
      .width('100%')
      if (this.safetyNotice.length > 0) {
        Text(this.safetyNotice)
          .width('100%')
          .fontSize(11)
          .lineHeight(17)
          .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
          .padding(10)
          .backgroundColor('#FFFFF8E8')
          .borderRadius(12)
      }
    }
    .width('calc(100% - 32vp)')
    .padding(10)
    .margin({ left: 16, right: 16, bottom: 6 })
    .backgroundColor('#BFFFFFFF')
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: AppConstants.COLOR_CARD_BORDER })
    .borderRadius(18)
  }

  @Builder
  AgentChip(name: string, value: string) {
    Column({ space: 3 }) {
      Text(name)
        .fontSize(10)
        .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
        .maxLines(1)
      Text(value)
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppConstants.COLOR_PRIMARY)
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(46)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F3F8FF')
    .border({ width: 1, color: '#E3EEFF' })
    .borderRadius(14)
  }

  @Builder
  ChatCompanionPanel() {
    Row({ space: 12 }) {
      Image($rawfile('kxq_ip_sleepy_chat.png'))
        .width(72)
        .height(72)
        .objectFit(ImageFit.Contain)
      Column({ space: 5 }) {
        Row({ space: 6 }) {
          Column()
            .width(8)
            .height(8)
            .borderRadius(4)
            .backgroundColor('#24C56A')
          Text('小晴在线陪伴中')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
        }
        Text('我在这里，慢慢听你说。')
          .fontSize(12)
          .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
          .maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('>')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#6D7D93')
    }
    .width('calc(100% - 32vp)')
    .height(94)
    .padding({ left: 14, right: 16 })
    .margin({ left: 16, right: 16, bottom: 8 })
    .backgroundColor('#D9FFFFFF')
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: AppConstants.COLOR_CARD_BORDER })
    .borderRadius(24)
    .onClick(() => {
      this.showCoachIntro = true;
    })
  }

  @Builder
  CompanionMode(icon: Resource, title: string, subtitle: string) {
    Column({ space: 5 }) {
      Image(icon)
        .width(58)
        .height(58)
        .objectFit(ImageFit.Contain)
      Text(title)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
        .maxLines(1)
      Text(subtitle)
        .fontSize(10)
        .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(108)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#BFFFFFFF')
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: AppConstants.COLOR_CARD_BORDER })
    .borderRadius(20)
    .onClick(() => {
      this.showCoachIntro = title === '安全提示';
    })
  }

  @Builder
  CoachIntroOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#730A1730')
        .backgroundBlurStyle(BlurStyle.Thin)

      Column({ space: 13 }) {
        Row({ space: 12 }) {
          Image($rawfile('agent_avatar.png'))
            .width(66)
            .height(66)
            .objectFit(ImageFit.Cover)
            .borderRadius(22)
          Column({ space: 4 }) {
            Text('不是一个人在回答')
              .fontSize(21)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
            Text('四个 Agent 协作完成')
              .fontSize(12)
              .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')

        this.AgentRole($r('sys.symbol.message'), '统筹', '整理上下文，生成最终回复', '#007DFF')
        this.AgentRole($r('sys.symbol.heart'), '听澜', '先听见情绪与真正需要', '#7A67D8')
        this.AgentRole($r('sys.symbol.eye'), '明镜', '识别认知偏差，提出关键问题', '#3E78C7')
        this.AgentRole($r('sys.symbol.clock'), '拾光', '把焦虑落成一个可行动小步骤', '#B66B23')

        Text('联网时听澜、明镜、拾光并行分析，再由统筹统一表达；未配置 API Key 时使用本地 CBT 规则，不会假装已联网。')
          .width('100%')
          .fontSize(11)
          .lineHeight(18)
          .fontColor(AppConstants.COLOR_TEXT_TERTIARY)
          .padding(10)
          .backgroundColor('#66F0F5FF')
          .borderRadius(12)

        Button('开始找小晴')
          .width('100%')
          .height(48)
          .fontSize(15)
          .fontColor(AppConstants.COLOR_WHITE)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .onClick(() => {
            this.showCoachIntro = false;
          })
      }
      .width('calc(100% - 44vp)')
      .padding(18)
      .backgroundColor('#F7FFFFFF')
      .backgroundBlurStyle(BlurStyle.Thick)
      .borderRadius(28)
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
  AgentRole(icon: Resource, name: string, detail: string, color: string) {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(40)
          .height(40)
          .borderRadius(14)
          .backgroundColor('#12007DFF')
        SymbolGlyph(icon)
          .fontSize(21)
          .fontColor([color])
      }
      Column({ space: 2 }) {
        Text(name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
        Text(detail)
          .fontSize(11)
          .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .backgroundColor('#66FFFFFF')
    .borderRadius(14)
  }
}
