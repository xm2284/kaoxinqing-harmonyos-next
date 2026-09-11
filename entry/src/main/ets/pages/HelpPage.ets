import { UiTokens } from '../common/UiTokens';
import { FeedbackRecord } from '../common/DataModels';
import { PageHeader } from '../components/PageHeader';
import { DatabaseService } from '../services/DatabaseService';

interface HelpItem { title: string; answer: string; }
@Entry
@Component
struct HelpPage {
  @State expanded: number = 0;
  @State feedback: string = '';
  @State category: string = '使用问题';
  @State saving: boolean = false;
  @State records: FeedbackRecord[] = [];
  private readonly questions: HelpItem[] = [
    { title: '如何修改首页考试和个人昵称？', answer: '点击首页考试旁的“修改”，或进入“我的 → 目标与计划”，可以编辑同一份考试信息。昵称、年级和学校在“我的 → 设置”中修改，保存后自动同步。' },
    { title: '没有 API Key 也能聊天吗？', answer: '可以。听澜心语默认提供本地场景回复，按话题和最近聊天选择内容；它不是在线大模型。设置中保存 DeepSeek API Key 后才会尝试连接在线服务。' },
    { title: '翻卡会重复吗？记录在哪里？', answer: '卡片库在一轮用完前不重复，退出重进也保留抽取进度。用完整轮后开始新的随机轮次。翻开的卡片会保存在“我的记录 → 翻卡”中。' },
    { title: '反馈会发送到哪里？', answer: '当前版本还没有接入客服后台。反馈只保存在本机，不会自动发送给开发者；你可以在下面查看已保存内容，再自行向开发者提供。' },
    { title: '出现很难熬的时刻怎么办？', answer: '“我的”页最下方有心理支持入口，可查看12356和紧急求助方式。若已经受伤或处于迫近危险，请立即联系120/110或就近急诊。应用不能代替专业帮助。' }
  ];
  aboutToAppear(): void { this.load(); }
  private async load(): Promise<void> {
    try { this.records = await DatabaseService.getFeedback(); }
    catch (reason) { this.toast('反馈记录未能加载。'); }
  }
  private toast(message: string): void { this.getUIContext().getPromptAction().showToast({ message: message }); }
  private async save(): Promise<void> {
    if (this.saving) { return; }
    if (this.feedback.trim().length < 5) { this.toast('请至少写 5 个字，帮助描述问题。'); return; }
    this.saving = true;
    try {
      await DatabaseService.addFeedback(this.category, this.feedback.trim());
      this.feedback = ''; await this.load(); this.toast('已保存到本机，尚未发送给开发者。');
    } catch (reason) { this.toast('保存失败，输入已保留。'); }
    finally { this.saving = false; }
  }
  build() {
    Column() {
      PageHeader({ title: '帮助与反馈' })
      Scroll() {
        Column({ space: 12 }) {
          Text('遇到问题，慢慢解决。').fontSize(22).fontWeight(FontWeight.Medium).width('100%')
          ForEach(this.questions, (item: HelpItem, index: number) => {
            Column({ space: 8 }) {
              Button({ type: ButtonType.Normal }) {
                Row() {
                  Text(item.title).fontSize(14).fontColor(UiTokens.TEXT_PRIMARY).layoutWeight(1).textAlign(TextAlign.Start)
                  Text(this.expanded === index ? '−' : '+').fontSize(22).fontColor(UiTokens.PRIMARY)
                }.width('100%')
              }.width('100%').height(48).backgroundColor(Color.Transparent).padding(0)
                .onClick(() => { this.expanded = this.expanded === index ? -1 : index; })
              if (this.expanded === index) { Text(item.answer).fontSize(13).lineHeight(21).fontColor(UiTokens.TEXT_SECONDARY).width('100%') }
            }.width('100%').padding({ left: 14, right: 14, bottom: 12 }).backgroundColor(Color.White).borderRadius(18)
          })
          Column({ space: 10 }) {
            Text('写一条反馈').fontSize(17).fontWeight(FontWeight.Bold).width('100%')
            Row({ space: 8 }) {
              ForEach(['使用问题', '功能建议', '其他'], (item: string) => {
                Button(item).layoutWeight(1).height(44).fontSize(12).fontColor(this.category === item ? Color.White : UiTokens.PRIMARY)
                  .backgroundColor(this.category === item ? UiTokens.PRIMARY : '#EAF4FF').onClick(() => { this.category = item; })
              })
            }.width('100%')
            TextArea({ placeholder: '发生了什么？在哪个页面？不必填写密码或私人信息。', text: this.feedback })
              .height(120).fontSize(14).maxLength(1000).onChange((value: string) => { this.feedback = value; })
            Button(this.saving ? '正在保存…' : '保存反馈到本机').width('100%').height(46).enabled(!this.saving)
              .backgroundColor(UiTokens.PRIMARY).onClick(() => { this.save(); })
            Text('尚未接入客服后台，保存后不会自动发送。').fontSize(11).fontColor(UiTokens.TEXT_SECONDARY)
          }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(20)
          if (this.records.length > 0) {
            Text('本机反馈记录').fontSize(17).fontWeight(FontWeight.Bold).width('100%')
            ForEach(this.records, (item: FeedbackRecord) => {
              Column({ space: 6 }) {
                Text(item.category + ' · ' + item.createdAt.substring(0, 10) + ' · 未发送').fontSize(11).fontColor(UiTokens.TEXT_SECONDARY)
                Text(item.content).fontSize(14).copyOption(CopyOptions.LocalDevice).fontColor(UiTokens.TEXT_PRIMARY)
              }.width('100%').alignItems(HorizontalAlign.Start).padding(14).backgroundColor(Color.White).borderRadius(18)
            }, (item: FeedbackRecord) => (item.id ?? 0).toString())
          }
        }.width('100%').constraintSize({ maxWidth: 680 }).padding({ left: 16, right: 16, top: 12, bottom: 24 })
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor(UiTokens.PAGE_BG_TOP)
  }
}
