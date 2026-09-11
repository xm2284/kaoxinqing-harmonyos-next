// 考心晴 - EntryAbility
// Ability生命周期 + 分布式续接检测 + 小艺语音Want处理

import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DistributeService } from '../services/DistributeService';
import { ApiService } from '../services/ApiService';
import { DatabaseService } from '../services/DatabaseService';
import { MemeService } from '../services/MemeService';
import { AppSettings, SettingsService } from '../services/SettingsService';
import { ExamInfo } from '../common/DataModels';

const DOMAIN: number = 0x0000;
const TAG: string = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  private distributeService: DistributeService = new DistributeService();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
    this.initializeAppStorage();
    this.handleWant(want);
    this.restoreContinuationParameters(want);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');
    this.prepareAndLoad(windowStage);
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');

    // 检测分布式续接状态
    this.checkContinuation();
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
    this.persistState();
  }

  onContinue(wantParam: Record<string, Object>): AbilityConstant.OnContinueResult {
    wantParam['pressureLevel'] = AppStorage.get<number>('pressureLevel') ?? 3;
    wantParam['studyProgress'] = AppStorage.get<number>('taskProgress') ?? 0;
    wantParam['currentAssessment'] = AppStorage.get<string>('currentAssessment') ?? '';
    wantParam['targetTab'] = AppStorage.get<number>('targetTab') ?? 0;
    wantParam['expandSection'] = AppStorage.get<string>('expandSection') ?? '';
    hilog.info(DOMAIN, TAG, 'Continuation state prepared');
    return AbilityConstant.OnContinueResult.AGREE;
  }

  // 检测是否有可续接的任务
  private async checkContinuation(): Promise<void> {
    try {
      const state: Record<string, string> = await this.distributeService.getContinuationState();
      const currentAssessment: string = state['currentAssessment'] ?? '';
      const pressureLevel: number = parseFloat(state['pressureLevel'] ?? '');
      const studyProgress: number = parseFloat(state['studyProgress'] ?? '');
      if (!isNaN(pressureLevel)) {
        AppStorage.setOrCreate('pressureLevel', pressureLevel);
      }
      if (!isNaN(studyProgress)) {
        AppStorage.setOrCreate('taskProgress', studyProgress);
      }
      if (currentAssessment.length > 0) {
        // 有未完成的测评任务，提示续接
        hilog.info(DOMAIN, TAG, 'Found continuation task');
        AppStorage.setOrCreate('hasContinuation', true);
        AppStorage.setOrCreate('continuationData', currentAssessment);
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Check continuation failed');
    }
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onNewWant');
    this.handleWant(want);
    this.restoreContinuationParameters(want);
  }

  private handleWant(want: Want): void {
    const params: Record<string, string> = want.parameters !== undefined ?
      want.parameters as Record<string, string> : {};
    const action: string = want.action ?? params['action'] ?? '';

    if (action === 'action.kaoxinqing.breathing') {
      AppStorage.setOrCreate('pendingRoute', 'pages/RelaxationPage');
    } else if (action === 'action.kaoxinqing.pressure') {
      AppStorage.setOrCreate('pendingRoute', 'pages/AssessmentRoutePage');
    } else if (action === 'action.kaoxinqing.coach') {
      AppStorage.setOrCreate('targetTab', 1);
      AppStorage.setOrCreate('expandSection', '');
    } else if (action === 'action.kaoxinqing.encouragement') {
      AppStorage.setOrCreate('targetTab', 1);
      AppStorage.setOrCreate('expandSection', 'affirmation');
      AppStorage.setOrCreate('playLatestAffirmation', true);
    } else if (action === 'action.kaoxinqing.home') {
      AppStorage.setOrCreate('targetTab', 0);
      AppStorage.setOrCreate('expandSection', '');
    }
  }

  private restoreContinuationParameters(want: Want): void {
    if (want.parameters === undefined) {
      return;
    }
    const params: Record<string, Object> = want.parameters as Record<string, Object>;
    const pressure: Object | undefined = params['pressureLevel'];
    const progress: Object | undefined = params['studyProgress'];
    const assessment: Object | undefined = params['currentAssessment'];
    const targetTab: Object | undefined = params['targetTab'];
    const section: Object | undefined = params['expandSection'];

    if (typeof pressure === 'number') {
      AppStorage.setOrCreate('pressureLevel', pressure);
    }
    if (typeof progress === 'number') {
      AppStorage.setOrCreate('taskProgress', progress);
    }
    if (typeof assessment === 'string') {
      AppStorage.setOrCreate('currentAssessment', assessment);
      AppStorage.setOrCreate('hasContinuation', assessment.length > 0);
    }
    if (typeof targetTab === 'number') {
      AppStorage.setOrCreate('targetTab', targetTab);
    }
    if (typeof section === 'string') {
      AppStorage.setOrCreate('expandSection', section);
    }
  }

  private async persistState(): Promise<void> {
    const pressure: number = AppStorage.get<number>('pressureLevel') ?? 3;
    const progress: number = AppStorage.get<number>('taskProgress') ?? 0;
    const assessment: string = AppStorage.get<string>('currentAssessment') ?? '';
    await this.distributeService.put('pressureLevel', pressure.toString());
    await this.distributeService.put('studyProgress', progress.toString());
    await this.distributeService.put('currentAssessment', assessment);
    await this.distributeService.put('examInfoJson', AppStorage.get<string>('examInfoJson') ?? '');
  }

  private initializeAppStorage(): void {
    AppStorage.setOrCreate('pressureLevel', 3);
    AppStorage.setOrCreate('taskProgress', 0);
    AppStorage.setOrCreate('targetTab', 0);
    AppStorage.setOrCreate('expandSection', '');
    AppStorage.setOrCreate('hasContinuation', false);
    AppStorage.setOrCreate('continuationData', '');
    AppStorage.setOrCreate('currentAssessment', '');
    AppStorage.setOrCreate('pendingRoute', '');
    AppStorage.setOrCreate('dataRefreshVersion', 0);
    AppStorage.setOrCreate('playLatestAffirmation', false);
    AppStorage.setOrCreate('privacyMode', false);
    AppStorage.setOrCreate('memeEnabled', true);
    AppStorage.setOrCreate('syncedWeakSubjects', '');
    AppStorage.setOrCreate('profileName', '小晴同学');
    AppStorage.setOrCreate('profileGrade', '大学二年级');
    AppStorage.setOrCreate('profileSchool', '我的大学');
    AppStorage.setOrCreate('examInfoJson',
      '{"name":"期末考试","date":"2026-12-20","subjects":["高等数学","大学英语","政治"],' +
      '"createdAt":"2026-08-28"}');
    AppStorage.setOrCreate('todayTasksJson',
      '[{"id":1,"title":"数学 - 函数与导数复习","completed":false,"date":"2026-07-25"},' +
      '{"id":2,"title":"英语 - 阅读理解练习","completed":true,"date":"2026-07-25"},' +
      '{"id":3,"title":"物理 - 力学公式梳理","completed":false,"date":"2026-07-25"},' +
      '{"id":4,"title":"数学 - 历年真题模拟","completed":false,"date":"2026-07-25"}]');
    AppStorage.setOrCreate('assessmentRecordsJson', '[]');
    AppStorage.setOrCreate('trainingRecordsJson', '[]');
    AppStorage.setOrCreate('examScoresJson', '[]');
    AppStorage.setOrCreate('growthEntriesJson',
      '[{"date":"2026-07-24","situation":"数学考试前非常紧张",' +
      '"automaticThought":"我一定会考砸","distortionType":"灾难化",' +
      '"alternativeThought":"我做了充分准备，结果不一定只有最坏的一种"}]');
    AppStorage.setOrCreate('dailyReminder', true);
    AppStorage.setOrCreate('pressureThreshold', 7);
    AppStorage.setOrCreate('apiKey', '');
  }

  private async prepareAndLoad(windowStage: window.WindowStage): Promise<void> {
    await DatabaseService.initDB(this.context);
    await ApiService.init(this.context);
    await MemeService.init(this.context);
    await SettingsService.init(this.context);
    const settings: AppSettings = await SettingsService.load();
    AppStorage.setOrCreate('dailyReminder', settings.dailyReminder);
    AppStorage.setOrCreate('privacyMode', settings.privacyMode);
    await this.distributeService.init(this.context);
    await this.hydratePersistedState();
    await this.syncExamSnapshotFromDatabase();
    windowStage.loadContent('pages/SplashPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });
  }

  private async hydratePersistedState(): Promise<void> {
    const stringKeys: string[] = [
      'currentAssessment', 'examInfoJson'
    ];
    for (let i = 0; i < stringKeys.length; i++) {
      const value: string = await this.distributeService.get(stringKeys[i]);
      if (value.length > 0) {
        AppStorage.setOrCreate(stringKeys[i], value);
      }
    }

    const savedPressure: string = await this.distributeService.get('pressureLevel');
    const savedProgress: string = await this.distributeService.get('studyProgress');
    const pressure: number = parseFloat(savedPressure);
    const progress: number = parseFloat(savedProgress);
    if (!isNaN(pressure)) {
      AppStorage.setOrCreate('pressureLevel', pressure);
    }
    if (!isNaN(progress)) {
      AppStorage.setOrCreate('taskProgress', progress);
    }
    const apiKey: string = await ApiService.getApiKey();
    if (apiKey.length > 0) {
      AppStorage.setOrCreate('apiKey', apiKey);
    }
  }

  private async syncExamSnapshotFromDatabase(): Promise<void> {
    try {
      const exams: ExamInfo[] = await DatabaseService.getAllExamInfo();
      if (exams.length === 0) {
        return;
      }
      const snapshot: string = JSON.stringify(exams[0]);
      if (!AppStorage.set<string>('examInfoJson', snapshot)) {
        AppStorage.setOrCreate('examInfoJson', snapshot);
      }
      await this.distributeService.put('examInfoJson', snapshot);
    } catch (reason) {
      hilog.warn(DOMAIN, TAG, 'Exam snapshot sync skipped');
    }
  }
}
