import { common } from '@kit.AbilityKit';
import { AppConstants, ExamInfo, StudyTask } from '../common/DataModels';
import { AdaptiveLayout } from '../common/AdaptiveLayout';
import { UiTokens } from '../common/UiTokens';
import { DatabaseService } from '../services/DatabaseService';
import { DistributeService } from '../services/DistributeService';
import { LiveViewService } from '../service/LiveViewService';

@Entry
@Component
struct CountdownSettingPage {
  @State editingId: number = -1;
  @State exams: ExamInfo[] = [];
  @State tasks: StudyTask[] = [];
  @State examName: string = '';
  @State examDate: string = '';
  @State subjectsText: string = '';
  @State important: boolean = false;
  @State saving: boolean = false;
  @State loading: boolean = true;
  @State loadFailed: boolean = false;
  @State liveViewActive: boolean = false;
  @State taskTitle: string = '';
  @State taskImportant: boolean = true;
  @State taskSaving: boolean = false;
  private createdAt: string = '';
  private readonly liveView: LiveViewService = new LiveViewService('考试倒计时', 'kaoxinqing_exam', 20260909);
  private readonly distribute: DistributeService = new DistributeService();

  aboutToAppear(): void { this.loadExams(); }
  aboutToDisappear(): void { this.liveView.stop(false, '考试计划已关闭'); }

  private async loadExams(): Promise<void> {
    this.loading = true; this.loadFailed = false;
    try {
      this.exams = await DatabaseService.getAllExamInfo();
      this.tasks = await DatabaseService.getAllTasks();
      const sorted: ExamInfo[] = this.sortedExams();
      if (sorted.length > 0) { this.editExam(sorted[0]); this.publishExamSnapshot(JSON.stringify(sorted[0])); }
      else { this.clearEditor(); this.publishExamSnapshot(''); }
    } catch (reason) { this.loadFailed = true; this.showToast('考试信息暂时没有加载出来。'); }
    finally { this.loading = false; }
  }

  private editExam(item: ExamInfo): void {
    this.editingId = item.id === undefined ? -1 : item.id;
    this.examName = item.name; this.examDate = item.date; this.subjectsText = item.subjects.join('、');
    this.important = item.important === true; this.createdAt = item.createdAt ?? '';
  }

  private clearEditor(): void {
    this.editingId = -1; this.examName = ''; this.examDate = ''; this.subjectsText = '';
    this.important = false; this.createdAt = '';
  }

  private startNewExam(): void { this.clearEditor(); this.showToast('已准备新的考试计划。'); }

  private sortedExams(): ExamInfo[] {
    return this.exams.slice().sort((a: ExamInfo, b: ExamInfo) => {
      if ((a.important === true) !== (b.important === true)) { return a.important === true ? -1 : 1; }
      const daysA: number = AdaptiveLayout.daysUntil(a.date); const daysB: number = AdaptiveLayout.daysUntil(b.date);
      if (daysA !== daysB) { return daysA - daysB; }
      return (b.createdAt ?? '').localeCompare(a.createdAt ?? '');
    });
  }

  private primaryExam(): ExamInfo | undefined {
    const sorted: ExamInfo[] = this.sortedExams(); return sorted.length > 0 ? sorted[0] : undefined;
  }

  private importantExams(): ExamInfo[] { return this.sortedExams().filter((item: ExamInfo) => item.important === true); }

  private importantTasks(): StudyTask[] {
    return this.tasks.filter((item: StudyTask) => item.important === true && !item.completed);
  }

  private normalTasks(): StudyTask[] {
    return this.sortedTasks().filter((item: StudyTask) => item.important !== true || item.completed);
  }

  private sortedTasks(): StudyTask[] {
    return this.tasks.slice().sort((a: StudyTask, b: StudyTask) => {
      if (a.completed !== b.completed) { return a.completed ? 1 : -1; }
      if ((a.important === true) !== (b.important === true)) { return a.important === true ? -1 : 1; }
      return a.date.localeCompare(b.date);
    });
  }

  private async addTask(): Promise<void> {
    const title: string = this.taskTitle.trim();
    if (this.taskSaving || title.length === 0) { this.showToast('先写下一个要完成的事项。'); return; }
    if (title.length > 40) { this.showToast('待办事项最多 40 个字。'); return; }
    this.taskSaving = true;
    try {
      const task: StudyTask = { title: title, completed: false, date: new Date().toISOString().substring(0, 10), important: this.taskImportant };
      task.id = await DatabaseService.addTask(task);
      this.tasks = [task].concat(this.tasks); this.taskTitle = '';
      DatabaseService.notifyChanged(); this.showToast(this.taskImportant ? '重点待办已加入。' : '待办已加入。');
    } catch (reason) { this.showToast('待办没有保存成功，请重试。'); }
    finally { this.taskSaving = false; }
  }

  private async toggleTask(item: StudyTask, completed: boolean): Promise<void> {
    if (item.id === undefined) { return; }
    const updated: StudyTask = { id: item.id, title: item.title, date: item.date, completed: completed, important: item.important };
    try { await DatabaseService.updateTask(updated); this.tasks = this.tasks.map((task: StudyTask) => task.id === item.id ? updated : task); DatabaseService.notifyChanged(); }
    catch (reason) { this.showToast('待办状态没有同步成功。'); }
  }

  private async deleteTask(item: StudyTask): Promise<void> {
    if (item.id === undefined) { return; }
    try { await DatabaseService.deleteTask(item.id); this.tasks = this.tasks.filter((task: StudyTask) => task.id !== item.id); DatabaseService.notifyChanged(); this.showToast('待办已删除。'); }
    catch (reason) { this.showToast('待办没有删除成功。'); }
  }

  private daysLabel(date: string): string {
    const days: number = AdaptiveLayout.daysUntil(date);
    if (days < 0) { return '已结束 ' + Math.abs(days).toString() + ' 天'; }
    return days === 0 ? '今天' : '还有 ' + days.toString() + ' 天';
  }

  private showDatePicker(): void {
    const selectedDate: Date = this.examDate.length > 0 ? new Date(this.examDate) : new Date();
    this.getUIContext().showDatePickerDialog({
      start: new Date(), end: new Date(2036, 11, 31), selected: selectedDate,
      onAccept: (value: DatePickerResult) => {
        const yearValue: number = value.year ?? selectedDate.getFullYear();
        const monthValue: number = value.month ?? selectedDate.getMonth();
        const dayValue: number = value.day ?? selectedDate.getDate();
        this.examDate = yearValue.toString() + '-' + (monthValue + 1).toString().padStart(2, '0') + '-' + dayValue.toString().padStart(2, '0');
      }
    });
  }

  private subjects(): string[] {
    const source: string[] = this.subjectsText.replace(/，/g, '、').replace(/,/g, '、').split('、');
    const result: string[] = [];
    for (let index: number = 0; index < source.length; index++) {
      const item: string = source[index].trim(); if (item.length > 0 && result.indexOf(item) < 0) { result.push(item); }
    }
    return result;
  }

  private async saveExam(): Promise<void> {
    if (this.saving || this.loading || this.loadFailed) { return; }
    if (this.examName.trim().length === 0 || this.examDate.length === 0 || this.subjects().length === 0) {
      this.showToast('把考试名称、日期和科目补充完整吧。'); return;
    }
    if (this.examName.trim().length > 24 || this.subjects().length > 12) { this.showToast('考试名称最多 24 个字，复习科目最多 12 门。'); return; }
    this.saving = true;
    const item: ExamInfo = { name: this.examName.trim(), date: this.examDate, subjects: this.subjects(), important: this.important,
      createdAt: this.createdAt.length > 0 ? this.createdAt : new Date().toISOString() };
    try {
      if (this.editingId > 0) { item.id = this.editingId; await DatabaseService.updateExamInfo(item); }
      else { item.id = await DatabaseService.addExamInfo(item); this.editingId = item.id; }
      this.exams = this.exams.filter((entry: ExamInfo) => entry.id !== item.id).concat([item]);
      const primary: ExamInfo | undefined = this.primaryExam(); if (primary !== undefined) { this.publishExamSnapshot(JSON.stringify(primary)); }
      this.notifyDataChanged(); this.showToast(this.important ? '重点计划已保存并置顶。' : '考试计划已保存。');
    } catch (reason) { this.showToast('考试信息没有保存成功，再试一次？'); }
    finally { this.saving = false; }
  }

  private confirmDelete(item?: ExamInfo): void {
    const id: number = item?.id ?? this.editingId;
    if (id <= 0 || this.saving || this.loading) { return; }
    this.getUIContext().getPromptAction().showDialog({ title: '删除考试计划', message: '删除后首页将不再显示这个倒计时，确定吗？',
      buttons: [{ text: '取消', color: AppConstants.COLOR_TEXT_SECONDARY }, { text: '删除', color: AppConstants.COLOR_DANGER }] }).then((result) => {
        if (result.index === 1) { this.deleteExam(id); }
      });
  }

  private async deleteExam(id: number): Promise<void> {
    if (this.saving) { return; }
    this.saving = true;
    try {
      await DatabaseService.deleteExamInfo(id); this.exams = this.exams.filter((item: ExamInfo) => item.id !== id);
      const next: ExamInfo | undefined = this.primaryExam();
      if (next !== undefined) { this.editExam(next); this.publishExamSnapshot(JSON.stringify(next)); }
      else { this.clearEditor(); this.publishExamSnapshot(''); }
      this.notifyDataChanged(); this.showToast('考试计划已删除。');
    } catch (reason) { this.showToast('刚才没有删除成功，再试一次？'); }
    finally { this.saving = false; }
  }

  private async startExamLiveView(): Promise<void> {
    const primary: ExamInfo | undefined = this.primaryExam();
    if (primary === undefined) { this.showToast('先保存一个考试计划，再开启实况窗。'); return; }
    if (this.liveViewActive) { await this.liveView.stop(false, '考试实况窗已关闭'); this.liveViewActive = false; this.showToast('实况窗已关闭。'); return; }
    const seconds: number = Math.max(60, AdaptiveLayout.daysUntil(primary.date) * 86400);
    this.liveViewActive = await this.liveView.start(this.daysLabel(primary.date), seconds);
    this.showToast(this.liveViewActive ? '考试倒计时已显示在实况窗。' : '当前设备暂不支持实况窗，应用内倒计时仍可用。');
  }

  private showWidgetGuide(): void {
    this.getUIContext().getPromptAction().showDialog({ title: '添加桌面卡片',
      message: '长按桌面进入编辑，选择“窗口小工具”，添加“考心晴压力卡片”。卡片会同步考试倒计时、压力指数和学习进度。',
      buttons: [{ text: '知道了', color: UiTokens.PRIMARY }] });
  }

  private async syncToDevices(): Promise<void> {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.distribute.init(context); const primary: ExamInfo | undefined = this.primaryExam();
      await this.distribute.put('examInfoJson', primary === undefined ? '' : JSON.stringify(primary));
      await this.distribute.put('examPlanUpdatedAt', new Date().toISOString()); this.showToast('已同步到可接续设备。');
    } catch (reason) { this.showToast('当前设备暂未发现可接续设备，计划仍已保存在本机。'); }
  }

  private showToast(message: string): void { this.getUIContext().getPromptAction().showToast({ message: message, duration: 2500 }); }
  private notifyDataChanged(): void { AppStorage.setOrCreate('dataRefreshVersion', (AppStorage.get<number>('dataRefreshVersion') ?? 0) + 1); }
  private publishExamSnapshot(value: string): void { AppStorage.setOrCreate('examInfoJson', value); }

  build() {
    Column() {
      this.TopBar()
      Scroll() {
        Column({ space: 14 }) {
          if (this.loading) { this.EmptyState('正在整理你的考试计划…'); }
          else if (this.loadFailed) { Button('重新加载考试信息').height(46).onClick(() => { this.loadExams(); }) }
          else { this.OverviewHero(); this.PrioritySection(); this.TaskSection(); this.AllPlansSection(); this.EditorSection(); this.HarmonySection(); }
        }.width('100%').constraintSize({ maxWidth: 720 }).padding({ left: 18, right: 18, bottom: 28 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor(UiTokens.PAGE_BG_TOP)
  }

  @Builder TopBar() {
    Row({ space: 12 }) {
      Button({ type: ButtonType.Circle }) { Image($rawfile('back_arrow.svg')).width(23).height(23) }
        .width(44).height(44).backgroundColor(Color.White).accessibilityText('返回').onClick(() => { this.getUIContext().getRouter().back(); })
      Column({ space: 3 }) { Text('考试与计划').fontSize(21).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
        Text(this.exams.length.toString() + ' 个计划 · 重点优先').fontSize(11).fontColor(UiTokens.TEXT_SECONDARY) }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button('+ 新增').height(42).padding({ left: 14, right: 14 }).fontSize(13).fontColor(UiTokens.PRIMARY)
        .backgroundColor(UiTokens.SURFACE_BLUE).borderRadius(UiTokens.BUTTON_RADIUS).onClick(() => { this.startNewExam(); })
    }.width('100%').padding({ left: 18, right: 18, top: 12, bottom: 10 })
  }

  @Builder OverviewHero() {
    Row({ space: 14 }) {
      Column({ space: 5 }) { Text(this.primaryExam() === undefined ? '从今天开始安排' : this.primaryExam()?.name ?? '')
        .fontSize(20).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.primaryExam() === undefined ? '把大目标拆成可完成的下一步' : (this.primaryExam()?.date ?? '') + '  ·  ' + this.daysLabel(this.primaryExam()?.date ?? ''))
          .fontSize(13).fontColor(UiTokens.TEXT_SECONDARY)
        Text(this.primaryExam() === undefined ? '添加第一个考试计划' : (this.primaryExam()?.subjects.length.toString() ?? '0') + ' 门科目 · 首页倒计时已同步')
          .fontSize(11).fontColor(UiTokens.PRIMARY) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column({ space: 2 }) { Text(this.primaryExam() === undefined ? '—' : Math.max(0, AdaptiveLayout.daysUntil(this.primaryExam()?.date ?? '')).toString())
        .fontSize(30).fontWeight(FontWeight.Bold).fontColor(UiTokens.PRIMARY); Text('剩余天数').fontSize(10).fontColor(UiTokens.TEXT_SECONDARY) }
        .width(72).alignItems(HorizontalAlign.End)
    }.width('100%').padding(18).backgroundColor(UiTokens.SURFACE_BLUE).borderRadius(UiTokens.HERO_RADIUS)
  }

  @Builder PrioritySection() {
    Column({ space: 10 }) {
      Row() { Column({ space: 3 }) { Text('重点完成').fontSize(18).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
        Text('优先处理这些计划，时间排序让位于重要性').fontSize(11).fontColor(UiTokens.TEXT_SECONDARY) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(this.importantExams().length.toString() + ' 项').fontSize(13).fontColor(UiTokens.PRIMARY) }.width('100%')
      if (this.importantExams().length === 0) { Row({ space: 10 }) { Text('☆').fontSize(22).fontColor(UiTokens.WARNING); Text('在编辑计划时打开“重点完成”，它会自动出现在这里。').fontSize(12).fontColor(UiTokens.TEXT_SECONDARY).layoutWeight(1) }.width('100%').padding(14).backgroundColor(Color.White).borderRadius(16) }
      else { ForEach(this.importantExams(), (item: ExamInfo) => { this.PlanCard(item, true); }, (item: ExamInfo) => 'priority-' + (item.id ?? item.name)); }
    }.width('100%')
  }

  @Builder AllPlansSection() {
    Column({ space: 10 }) { Row() { Text('全部计划').fontSize(18).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY).layoutWeight(1); Text('重点优先 · 剩余时间升序').fontSize(11).fontColor(UiTokens.TEXT_SECONDARY) }.width('100%')
      if (this.sortedExams().length === 0) { this.EmptyState('还没有计划，先添加一场考试吧。'); }
      else { ForEach(this.sortedExams(), (item: ExamInfo) => { this.PlanCard(item, false); }, (item: ExamInfo) => 'all-' + (item.id ?? item.name)); }
    }.width('100%')
  }

  @Builder TaskSection() {
    Column({ space: 10 }) {
      Row() { Column({ space: 3 }) { Text('重点待办').fontSize(18).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
        Text('把今天真正要完成的事写下来，完成后勾选即可归档').fontSize(11).fontColor(UiTokens.TEXT_SECONDARY) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(this.importantTasks().length.toString() + ' 项未完成').fontSize(11).fontColor(UiTokens.PRIMARY) }.width('100%')
      Row({ space: 8 }) { TextInput({ placeholder: '例如：完成数学真题第 3 章', text: this.taskTitle }).layoutWeight(1).height(46).fontSize(13).backgroundColor(Color.White).border({ width: 1, color: UiTokens.CARD_BORDER }).borderRadius(13).onChange((value: string) => { this.taskTitle = value; })
        Text('重点').fontSize(11).fontColor(UiTokens.TEXT_SECONDARY)
        Toggle({ type: ToggleType.Switch, isOn: this.taskImportant }).onChange((value: boolean) => { this.taskImportant = value; })
        Button('添加').height(46).width(58).fontSize(12).fontColor(Color.White).backgroundColor(UiTokens.PRIMARY).borderRadius(13).enabled(!this.taskSaving).onClick(() => { this.addTask(); }) }.width('100%')
      if (this.importantTasks().length > 0) {
        Text('重点待办').fontSize(12).fontWeight(FontWeight.Medium).fontColor(UiTokens.PRIMARY).width('100%').margin({ top: 4 })
        ForEach(this.importantTasks(), (item: StudyTask) => { this.TaskRow(item); }, (item: StudyTask) => 'priority-task-' + (item.id ?? item.title))
      }
      if (this.normalTasks().length > 0) {
        Text('其他待办').fontSize(12).fontWeight(FontWeight.Medium).fontColor(UiTokens.TEXT_SECONDARY).width('100%').margin({ top: 4 })
        ForEach(this.normalTasks(), (item: StudyTask) => { this.TaskRow(item); }, (item: StudyTask) => 'normal-task-' + (item.id ?? item.title))
      }
      if (this.sortedTasks().length === 0) { this.EmptyState('先添加一个今天要完成的待办。'); }
    }.width('100%').padding(16).backgroundColor('#F8FBFF').border({ width: 1, color: '#DCE9F8' }).borderRadius(UiTokens.CARD_RADIUS)
  }

  @Builder TaskRow(item: StudyTask) {
    Row({ space: 8 }) {
      Checkbox({ name: 'task-' + (item.id ?? item.title) }).select(item.completed).onChange((value: boolean) => { this.toggleTask(item, value); })
      Column({ space: 3 }) { Text(item.title).fontSize(13).fontColor(item.completed ? UiTokens.TEXT_MUTED : UiTokens.TEXT_PRIMARY).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.date + (item.completed ? ' · 已完成' : ' · 待完成')).fontSize(10).fontColor(UiTokens.TEXT_SECONDARY) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (item.important === true && !item.completed) { Text('重点').fontSize(10).fontColor('#9A6D2E').padding({ left: 6, right: 6, top: 3, bottom: 3 }).backgroundColor('#FFF2D0').borderRadius(8); }
      Button('删除').height(32).fontSize(10).fontColor(UiTokens.DANGER).backgroundColor(Color.Transparent).onClick(() => { this.deleteTask(item); })
    }.width('100%').padding({ top: 5, bottom: 5 })
  }

  @Builder PlanCard(item: ExamInfo, priority: boolean) {
    Row({ space: 12 }) { Column({ space: 5 }) {
        Row({ space: 7 }) { Text(item.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor(UiTokens.TEXT_PRIMARY).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          if (item.important === true) { Text('重点').fontSize(10).fontColor('#9A6D2E').padding({ left: 7, right: 7, top: 3, bottom: 3 }).backgroundColor('#FFF2D0').borderRadius(8); } }.width('100%')
        Text(item.date + '  ·  ' + this.daysLabel(item.date)).fontSize(12).fontColor(item.date < new Date().toISOString().substring(0, 10) ? UiTokens.DANGER : UiTokens.PRIMARY)
        Text(item.subjects.join('  ·  ')).fontSize(11).fontColor(UiTokens.TEXT_SECONDARY).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column({ space: 4 }) { Button('编辑').height(34).fontSize(11).fontColor(UiTokens.PRIMARY).backgroundColor(UiTokens.SURFACE_BLUE).borderRadius(12).onClick(() => { this.editExam(item); })
        Button('删除').height(34).fontSize(11).fontColor(UiTokens.DANGER).backgroundColor('#FFF1F0').borderRadius(12).onClick(() => { this.confirmDelete(item); }) }.width(52)
    }.width('100%').padding(14).backgroundColor(priority ? '#F8FBFF' : Color.White).border({ width: priority ? 1.5 : 1, color: priority ? '#BFD9FF' : UiTokens.CARD_BORDER }).borderRadius(18)
  }

  @Builder EditorSection() {
    Column({ space: 11 }) { Row() { Column({ space: 3 }) { Text(this.editingId > 0 ? '编辑计划' : '新增计划').fontSize(18).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY)
        Text('保存后会立即更新首页与桌面卡片数据').fontSize(11).fontColor(UiTokens.TEXT_SECONDARY) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (this.editingId > 0) { Text('ID ' + this.editingId.toString()).fontSize(10).fontColor(UiTokens.TEXT_MUTED); } }.width('100%')
      this.InputLabel('考试名称'); TextInput({ placeholder: '例如：期末考试、考研初试', text: this.examName }).height(48).fontSize(15).backgroundColor('#F6F9FD').borderRadius(14).onChange((value: string) => { this.examName = value; })
      this.InputLabel('考试日期'); Button(this.examDate.length === 0 ? '选择日期' : this.examDate).width('100%').height(48).fontSize(15).fontColor(this.examDate.length === 0 ? UiTokens.TEXT_MUTED : UiTokens.TEXT_PRIMARY).backgroundColor('#F6F9FD').borderRadius(14).onClick(() => { this.showDatePicker(); })
      this.InputLabel('复习科目'); TextInput({ placeholder: '用顿号分隔，例如：高等数学、大学英语', text: this.subjectsText }).height(48).fontSize(15).backgroundColor('#F6F9FD').borderRadius(14).onChange((value: string) => { this.subjectsText = value; })
      Row({ space: 12 }) { Column({ space: 3 }) { Text('重点完成').fontSize(15).fontWeight(FontWeight.Medium).fontColor(UiTokens.TEXT_PRIMARY); Text('置顶到重点待办，优先提醒').fontSize(11).fontColor(UiTokens.TEXT_SECONDARY) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.important }).onChange((value: boolean) => { this.important = value; }) }.width('100%').padding({ top: 4, bottom: 4 })
      Button(this.saving ? '正在保存…' : (this.editingId > 0 ? '保存修改' : '添加计划')).width('100%').height(48).enabled(!this.saving && !this.loading && !this.loadFailed).fontSize(16).fontWeight(FontWeight.Medium).fontColor(Color.White).backgroundColor(UiTokens.PRIMARY).borderRadius(UiTokens.BUTTON_RADIUS).onClick(() => { this.saveExam(); })
    }.width('100%').padding(16).backgroundColor(Color.White).border({ width: 1, color: UiTokens.CARD_BORDER }).borderRadius(UiTokens.CARD_RADIUS)
  }

  @Builder HarmonySection() {
    Column({ space: 10 }) { Row() { Column({ space: 3 }) { Text('鸿蒙协同').fontSize(18).fontWeight(FontWeight.Bold).fontColor(UiTokens.TEXT_PRIMARY); Text('把计划带到桌面、锁屏和其他设备').fontSize(11).fontColor(UiTokens.TEXT_SECONDARY) }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text('HarmonyOS').fontSize(10).fontColor(UiTokens.PRIMARY).padding({ left: 8, right: 8, top: 4, bottom: 4 }).backgroundColor(UiTokens.SURFACE_BLUE).borderRadius(8) }.width('100%')
      Row({ space: 8 }) { this.HarmonyAction('桌面卡片', '考试/压力/进度', () => { this.showWidgetGuide(); }); this.HarmonyAction('实况窗', this.liveViewActive ? '运行中' : '考试倒计时', () => { this.startExamLiveView(); }); this.HarmonyAction('分布式接续', '同步计划', () => { this.syncToDevices(); }); }.width('100%')
    }.width('100%').padding(16).backgroundColor('#F8FBFF').border({ width: 1, color: '#DCE9F8' }).borderRadius(UiTokens.CARD_RADIUS)
  }

  @Builder HarmonyAction(title: string, note: string, action: () => void) {
    Button({ type: ButtonType.Normal }) { Column({ space: 5 }) { Text(title).fontSize(13).fontWeight(FontWeight.Medium).fontColor(UiTokens.TEXT_PRIMARY); Text(note).fontSize(10).fontColor(UiTokens.TEXT_SECONDARY).maxLines(1); }.width('100%'); }.layoutWeight(1).height(68).padding(6).backgroundColor(Color.White).borderRadius(14).onClick(action)
  }

  @Builder EmptyState(message: string) { Row() { Text(message).fontSize(12).fontColor(UiTokens.TEXT_SECONDARY).width('100%').textAlign(TextAlign.Center); }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(16); }
  @Builder InputLabel(label: string) { Text(label).fontSize(13).fontWeight(FontWeight.Medium).fontColor(UiTokens.TEXT_SECONDARY).width('100%'); }
}
