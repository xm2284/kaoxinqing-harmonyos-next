import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import {
  Affirmation,
  AppConstants,
  AppUsage,
  AssessmentRecord,
  ChatMessage,
  CardDrawRecord,
  FeedbackRecord,
  DailyQuote,
  ExamInfo,
  ExamScore,
  MentalHealthRecord,
  StudyTask,
  ThoughtChallenge,
  TrainingRecord,
  UserProfile,
  VideoShare
} from '../common/DataModels';

const STORE_CONFIG: relationalStore.StoreConfig = {
  // v2 保留同一数据库文件并按需补表，避免破坏用户已有数据。
  name: 'kaoxinqing_v2.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

const CREATE_TABLE_SQL: string[] = [
  'CREATE TABLE IF NOT EXISTS card_deck_seen (content TEXT PRIMARY KEY)',
  'CREATE TABLE IF NOT EXISTS card_draw_records (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, content TEXT NOT NULL, category TEXT NOT NULL, drawnAt TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS feedback_records (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, category TEXT NOT NULL, content TEXT NOT NULL, createdAt TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS exam_info (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, date TEXT NOT NULL, ' +
    'subjects TEXT NOT NULL, important INTEGER NOT NULL DEFAULT 0, createdAt TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS tasks (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, completed INTEGER NOT NULL, date TEXT NOT NULL, ' +
    'important INTEGER NOT NULL DEFAULT 0)',
  'CREATE TABLE IF NOT EXISTS assessments (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, type TEXT NOT NULL, answers TEXT NOT NULL, ' +
    'totalScore INTEGER NOT NULL, stressLevel REAL NOT NULL)',
  'CREATE TABLE IF NOT EXISTS chat_messages (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, role TEXT NOT NULL, content TEXT NOT NULL, timestamp TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS training_records (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, type TEXT NOT NULL, duration INTEGER NOT NULL)',
  'CREATE TABLE IF NOT EXISTS mental_health_records (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, recordedAt TEXT NOT NULL, moodScore INTEGER NOT NULL, ' +
    'moodLabel TEXT NOT NULL, emotions TEXT NOT NULL, factors TEXT NOT NULL, note TEXT NOT NULL, ' +
    'source TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS exam_scores (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, subject TEXT NOT NULL, score REAL NOT NULL, fullScore REAL NOT NULL)',
  'CREATE TABLE IF NOT EXISTS daily_quotes (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, content TEXT NOT NULL, category TEXT NOT NULL, ' +
    'used INTEGER NOT NULL, date TEXT)',
  'CREATE TABLE IF NOT EXISTS user_profile (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, nickname TEXT NOT NULL, grade TEXT NOT NULL, school TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS affirmations (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL, originalText TEXT NOT NULL, ' +
    'filePath TEXT NOT NULL, duration INTEGER NOT NULL, createdAt TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS thought_challenges (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, negativeThought TEXT NOT NULL, alternativeThought TEXT NOT NULL, ' +
    'distortionType TEXT NOT NULL, createdAt TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS video_shares (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, bvid TEXT NOT NULL, coverUrl TEXT NOT NULL, title TEXT NOT NULL, ' +
    'shareReason TEXT NOT NULL, sharer TEXT NOT NULL, likes INTEGER NOT NULL, category TEXT NOT NULL, ' +
    'createdAt TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS app_usage (' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL UNIQUE, consecutiveDays INTEGER NOT NULL)'
];

export class DatabaseService {
  private static store: relationalStore.RdbStore | undefined = undefined;
  private static drawing: boolean = false;

  static async drawQuoteBatch(previous: DailyQuote[] = []): Promise<DailyQuote[]> {
    if (DatabaseService.drawing) { throw new Error('卡片正在准备'); }
    DatabaseService.drawing = true;
    const store: relationalStore.RdbStore = DatabaseService.requireStore();
    try {
      const all: DailyQuote[] = await DatabaseService.getAllDailyQuotes();
      const seen: Set<string> = new Set<string>();
      const recentSeen: string[] = [];
      const result: relationalStore.ResultSet = await store.query(new relationalStore.RdbPredicates('card_deck_seen').orderByAsc('rowid'));
      try {
        while (result.goToNextRow()) {
          const content: string = result.getString(result.getColumnIndex('content'));
          seen.add(content); recentSeen.push(content);
        }
      } finally { result.close(); }
      const unique: Set<string> = new Set<string>();
      const available: DailyQuote[] = all.filter((item: DailyQuote) => {
        if (unique.has(item.content)) { return false; }
        unique.add(item.content); return true;
      });
      if (available.length < 6) { throw new Error('可用卡片不足'); }
      let pool: DailyQuote[] = available.filter((item: DailyQuote) => !seen.has(item.content));
      const reset: boolean = pool.length < 6;
      const last: Set<string> = new Set<string>();
      previous.forEach((item: DailyQuote) => { last.add(item.content); });
      if (previous.length === 0) { recentSeen.slice(-6).forEach((content: string) => { last.add(content); }); }
      const carry: DailyQuote[] = pool.slice();
      if (reset) {
        const carryContents: Set<string> = new Set<string>();
        carry.forEach((item: DailyQuote) => { carryContents.add(item.content); });
        pool = available.filter((item: DailyQuote) => !last.has(item.content) && !carryContents.has(item.content));
        if (carry.length + pool.length < 6) {
          pool = available.filter((item: DailyQuote) => !carryContents.has(item.content));
        }
      }
      for (let index: number = pool.length - 1; index > 0; index--) {
        const next: number = Math.floor(Math.random() * (index + 1));
        const value: DailyQuote = pool[index]; pool[index] = pool[next]; pool[next] = value;
      }
      const selected: DailyQuote[] = reset ? carry.concat(pool).slice(0, 6) : pool.slice(0, 6);
      // 只在重新开始一轮时清空旧的已看集合；本轮候选卡要等真正翻开后再标记。
      if (reset) {
        store.beginTransaction();
        try {
          await store.executeSql('DELETE FROM card_deck_seen');
          store.commit();
        } catch (reason) { store.rollBack(); throw new Error('洗牌保存失败'); }
      }
      return selected;
    } finally { DatabaseService.drawing = false; }
  }

  static async addCardDraw(quote: DailyQuote): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      content: quote.content, category: quote.category, drawnAt: new Date().toISOString()
    };
    const store: relationalStore.RdbStore = DatabaseService.requireStore();
    await store.insert('card_draw_records', values);
    // PRIMARY KEY 冲突只代表这句话此前已看过，不应阻塞成长记录写入。
    try {
      await store.insert('card_deck_seen', { content: quote.content } as relationalStore.ValuesBucket);
    } catch (reason) {
      // 已看集合是去重辅助数据，重复或旧库异常不应影响成长记录。
    }
    DatabaseService.notifyChanged();
  }

  static async getCardDraws(): Promise<CardDrawRecord[]> {
    const result: relationalStore.ResultSet = await DatabaseService.requireStore().query(
      new relationalStore.RdbPredicates('card_draw_records').orderByDesc('id'));
    const items: CardDrawRecord[] = [];
    try {
      while (result.goToNextRow()) {
        items.push({ id: result.getLong(result.getColumnIndex('id')),
          content: result.getString(result.getColumnIndex('content')),
          category: result.getString(result.getColumnIndex('category')),
          drawnAt: result.getString(result.getColumnIndex('drawnAt')) });
      }
    } finally { result.close(); }
    return items;
  }

  static async addFeedback(category: string, content: string): Promise<void> {
    const values: relationalStore.ValuesBucket = { category: category, content: content, createdAt: new Date().toISOString() };
    await DatabaseService.requireStore().insert('feedback_records', values);
  }

  static async getFeedback(): Promise<FeedbackRecord[]> {
    const result: relationalStore.ResultSet = await DatabaseService.requireStore().query(
      new relationalStore.RdbPredicates('feedback_records').orderByDesc('id'));
    const items: FeedbackRecord[] = [];
    try {
      while (result.goToNextRow()) {
        items.push({ id: result.getLong(result.getColumnIndex('id')),
          content: result.getString(result.getColumnIndex('content')),
          category: result.getString(result.getColumnIndex('category')),
          createdAt: result.getString(result.getColumnIndex('createdAt')) });
      }
    } finally { result.close(); }
    return items;
  }

  static notifyChanged(): void {
    AppStorage.setOrCreate('dataRefreshVersion', (AppStorage.get<number>('dataRefreshVersion') ?? 0) + 1);
  }

  static async initDB(context: common.Context): Promise<void> {
    if (DatabaseService.store !== undefined) {
      return;
    }
    DatabaseService.store = await relationalStore.getRdbStore(context, STORE_CONFIG);
    for (let index: number = 0; index < CREATE_TABLE_SQL.length; index++) {
      await DatabaseService.store.executeSql(CREATE_TABLE_SQL[index]);
    }
    await DatabaseService.ensureExamInfoImportantColumn();
    await DatabaseService.ensureTaskImportantColumn();
    await DatabaseService.seedQuotes();
    await DatabaseService.seedVideos();
    await DatabaseService.seedProfile();
  }

  private static requireStore(): relationalStore.RdbStore {
    if (DatabaseService.store === undefined) {
      throw new Error('数据库尚未初始化');
    }
    return DatabaseService.store;
  }

  private static async ensureExamInfoImportantColumn(): Promise<void> {
    try {
      await DatabaseService.requireStore().executeSql(
        'ALTER TABLE exam_info ADD COLUMN important INTEGER NOT NULL DEFAULT 0');
    } catch (reason) {
      // 新数据库已在建表语句中包含该列，旧数据库则在首次启动时完成迁移。
    }
  }

  private static async ensureTaskImportantColumn(): Promise<void> {
    try {
      await DatabaseService.requireStore().executeSql(
        'ALTER TABLE tasks ADD COLUMN important INTEGER NOT NULL DEFAULT 0');
    } catch (reason) {
      // 新数据库已包含该列，旧数据库在首次启动时完成迁移。
    }
  }

  private static predicates(table: string, id: number): relationalStore.RdbPredicates {
    return new relationalStore.RdbPredicates(table).equalTo('id', id);
  }

  private static async tableIsEmpty(table: string): Promise<boolean> {
    const result: relationalStore.ResultSet =
      await DatabaseService.requireStore().query(new relationalStore.RdbPredicates(table));
    try {
      return result.rowCount === 0;
    } finally {
      result.close();
    }
  }

  private static async seedQuotes(): Promise<void> {
    // Backfill upgrades as well as first installs, without replacing saved quotes.
    const existing: DailyQuote[] = await DatabaseService.getAllDailyQuotes();
    const contents: Set<string> = new Set<string>();
    existing.forEach((quote: DailyQuote) => { contents.add(quote.content); });
    for (let index: number = 0; index < AppConstants.QUOTE_SEEDS.length; index++) {
      if (contents.has(AppConstants.QUOTE_SEEDS[index].content)) {
        continue;
      }
      const values: relationalStore.ValuesBucket = {
        content: AppConstants.QUOTE_SEEDS[index].content,
        category: AppConstants.QUOTE_SEEDS[index].category,
        used: 0,
        date: ''
      };
      await DatabaseService.requireStore().insert('daily_quotes', values);
      contents.add(AppConstants.QUOTE_SEEDS[index].content);
    }
  }

  private static async seedVideos(): Promise<void> {
    await DatabaseService.ensurePresetVideos();
  }

  static async ensurePresetVideos(): Promise<void> {
    for (let index: number = 0; index < AppConstants.PRESET_VIDEOS.length; index++) {
      const preset: VideoShare = AppConstants.PRESET_VIDEOS[index];
      const result: relationalStore.ResultSet = await DatabaseService.requireStore().query(
        new relationalStore.RdbPredicates('video_shares').equalTo('bvid', preset.bvid)
      );
      let exists: boolean = false;
      try {
        exists = result.goToFirstRow();
      } finally {
        result.close();
      }
      if (!exists) {
        await DatabaseService.addVideoShare(preset);
      }
    }
  }

  private static async seedProfile(): Promise<void> {
    if (!await DatabaseService.tableIsEmpty('user_profile')) {
      return;
    }
    await DatabaseService.addUserProfile({
      nickname: '小晴同学',
      grade: '大学二年级',
      school: '我的大学'
    });
  }

  static async getAllExamInfo(): Promise<ExamInfo[]> {
    const result: relationalStore.ResultSet = await DatabaseService.requireStore()
      .query(new relationalStore.RdbPredicates('exam_info')
        .orderByDesc('important').orderByAsc('date').orderByDesc('id'));
    const items: ExamInfo[] = [];
    try {
      while (result.goToNextRow()) {
        items.push({
          id: result.getLong(result.getColumnIndex('id')),
          name: result.getString(result.getColumnIndex('name')),
          date: result.getString(result.getColumnIndex('date')),
          subjects: JSON.parse(result.getString(result.getColumnIndex('subjects'))) as string[],
          important: result.getLong(result.getColumnIndex('important')) === 1,
          createdAt: result.getString(result.getColumnIndex('createdAt'))
        });
      }
    } finally {
      result.close();
    }
    return items;
  }

  static async addExamInfo(item: ExamInfo): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      name: item.name,
      date: item.date,
      subjects: JSON.stringify(item.subjects),
      important: item.important === true ? 1 : 0,
      createdAt: item.createdAt === undefined ? new Date().toISOString() : item.createdAt
    };
    return DatabaseService.requireStore().insert('exam_info', values);
  }

  static async updateExamInfo(item: ExamInfo): Promise<void> {
    if (item.id === undefined) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      name: item.name,
      date: item.date,
      subjects: JSON.stringify(item.subjects),
      important: item.important === true ? 1 : 0,
      createdAt: item.createdAt === undefined ? new Date().toISOString() : item.createdAt
    };
    await DatabaseService.requireStore().update(values, DatabaseService.predicates('exam_info', item.id));
  }

  static async deleteExamInfo(id: number): Promise<void> {
    await DatabaseService.requireStore().delete(DatabaseService.predicates('exam_info', id));
  }

  static async getAllTasks(): Promise<StudyTask[]> {
    const result: relationalStore.ResultSet = await DatabaseService.requireStore()
      .query(new relationalStore.RdbPredicates('tasks').orderByDesc('important').orderByAsc('date').orderByDesc('id'));
    const items: StudyTask[] = [];
    try {
      while (result.goToNextRow()) {
        items.push({
          id: result.getLong(result.getColumnIndex('id')),
          title: result.getString(result.getColumnIndex('title')),
          completed: result.getLong(result.getColumnIndex('completed')) === 1,
          date: result.getString(result.getColumnIndex('date')),
          important: result.getLong(result.getColumnIndex('important')) === 1
        });
      }
    } finally {
      result.close();
    }
    return items;
  }

  static async addTask(item: StudyTask): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      title: item.title,
      completed: item.completed ? 1 : 0,
      date: item.date,
      important: item.important === true ? 1 : 0
    };
    return DatabaseService.requireStore().insert('tasks', values);
  }

  static async updateTask(item: StudyTask): Promise<void> {
    if (item.id === undefined) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      title: item.title,
      completed: item.completed ? 1 : 0,
      date: item.date,
      important: item.important === true ? 1 : 0
    };
    await DatabaseService.requireStore().update(values, DatabaseService.predicates('tasks', item.id));
  }

  static async deleteTask(id: number): Promise<void> {
    await DatabaseService.requireStore().delete(DatabaseService.predicates('tasks', id));
  }

  static async getAllAssessments(): Promise<AssessmentRecord[]> {
    const result: relationalStore.ResultSet = await DatabaseService.requireStore()
      .query(new relationalStore.RdbPredicates('assessments').orderByDesc('id'));
    const items: AssessmentRecord[] = [];
    try {
      while (result.goToNextRow()) {
        items.push({
          id: result.getLong(result.getColumnIndex('id')),
          date: result.getString(result.getColumnIndex('date')),
          type: result.getString(result.getColumnIndex('type')),
          answers: JSON.parse(result.getString(result.getColumnIndex('answers'))) as number[],
          totalScore: result.getLong(result.getColumnIndex('totalScore')),
          stressLevel: result.getDouble(result.getColumnIndex('stressLevel'))
        });
      }
    } finally {
      result.close();
    }
    return items;
  }

  static async addAssessment(item: AssessmentRecord): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      date: item.date,
      type: item.type,
      answers: JSON.stringify(item.answers),
      totalScore: item.totalScore,
      stressLevel: item.stressLevel
    };
    return DatabaseService.requireStore().insert('assessments', values);
  }

  static async updateAssessment(item: AssessmentRecord): Promise<void> {
    if (item.id === undefined) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      date: item.date,
      type: item.type,
      answers: JSON.stringify(item.answers),
      totalScore: item.totalScore,
      stressLevel: item.stressLevel
    };
    await DatabaseService.requireStore().update(values, DatabaseService.predicates('assessments', item.id));
  }

  static async deleteAssessment(id: number): Promise<void> {
    await DatabaseService.requireStore().delete(DatabaseService.predicates('assessments', id));
  }

  static async getMentalHealthRecords(): Promise<MentalHealthRecord[]> {
    const result: relationalStore.ResultSet = await DatabaseService.requireStore().query(
      new relationalStore.RdbPredicates('mental_health_records').orderByDesc('recordedAt'));
    const items: MentalHealthRecord[] = [];
    try {
      while (result.goToNextRow()) {
        items.push({
          id: result.getLong(result.getColumnIndex('id')),
          recordedAt: result.getString(result.getColumnIndex('recordedAt')),
          moodScore: result.getLong(result.getColumnIndex('moodScore')),
          moodLabel: result.getString(result.getColumnIndex('moodLabel')),
          emotions: JSON.parse(result.getString(result.getColumnIndex('emotions'))) as string[],
          factors: JSON.parse(result.getString(result.getColumnIndex('factors'))) as string[],
          note: result.getString(result.getColumnIndex('note')),
          source: result.getString(result.getColumnIndex('source'))
        });
      }
    } finally {
      result.close();
    }
    return items;
  }

  static async addMentalHealthRecord(item: MentalHealthRecord): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      recordedAt: item.recordedAt,
      moodScore: item.moodScore,
      moodLabel: item.moodLabel,
      emotions: JSON.stringify(item.emotions),
      factors: JSON.stringify(item.factors),
      note: item.note,
      source: item.source
    };
    const id: number = await DatabaseService.requireStore().insert('mental_health_records', values);
    DatabaseService.notifyChanged();
    return id;
  }

  static async updateMentalHealthRecord(item: MentalHealthRecord): Promise<void> {
    if (item.id === undefined) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      recordedAt: item.recordedAt,
      moodScore: item.moodScore,
      moodLabel: item.moodLabel,
      emotions: JSON.stringify(item.emotions),
      factors: JSON.stringify(item.factors),
      note: item.note,
      source: item.source
    };
    await DatabaseService.requireStore().update(values,
      DatabaseService.predicates('mental_health_records', item.id));
    DatabaseService.notifyChanged();
  }

  static async deleteMentalHealthRecord(id: number): Promise<void> {
    await DatabaseService.requireStore().delete(DatabaseService.predicates('mental_health_records', id));
    DatabaseService.notifyChanged();
  }

  static async getAllChatMessages(): Promise<ChatMessage[]> {
    const result: relationalStore.ResultSet = await DatabaseService.requireStore()
      .query(new relationalStore.RdbPredicates('chat_messages').orderByAsc('id'));
    const items: ChatMessage[] = [];
    try {
      while (result.goToNextRow()) {
        items.push({
          id: result.getLong(result.getColumnIndex('id')),
          role: result.getString(result.getColumnIndex('role')),
          content: result.getString(result.getColumnIndex('content')),
          timestamp: result.getString(result.getColumnIndex('timestamp'))
        });
      }
    } finally {
      result.close();
    }
    return items;
  }

  static async addChatMessage(item: ChatMessage): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      role: item.role,
      content: item.content,
      timestamp: item.timestamp === undefined ? new Date().toISOString() : item.timestamp
    };
    return DatabaseService.requireStore().insert('chat_messages', values);
  }

  static async updateChatMessage(item: ChatMessage): Promise<void> {
    if (item.id === undefined) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      role: item.role,
      content: item.content,
      timestamp: item.timestamp === undefined ? new Date().toISOString() : item.timestamp
    };
    await DatabaseService.requireStore().update(values, DatabaseService.predicates('chat_messages', item.id));
  }

  static async deleteChatMessage(id: number): Promise<void> {
    await DatabaseService.requireStore().delete(DatabaseService.predicates('chat_messages', id));
  }

  static async getAllTrainingRecords(): Promise<TrainingRecord[]> {
    const result: relationalStore.ResultSet = await DatabaseService.requireStore()
      .query(new relationalStore.RdbPredicates('training_records').orderByDesc('id'));
    const items: TrainingRecord[] = [];
    try {
      while (result.goToNextRow()) {
        items.push({
          id: result.getLong(result.getColumnIndex('id')),
          date: result.getString(result.getColumnIndex('date')),
          type: result.getString(result.getColumnIndex('type')),
          duration: result.getLong(result.getColumnIndex('duration'))
        });
      }
    } finally {
      result.close();
    }
    return items;
  }

  static async addTrainingRecord(item: TrainingRecord): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      date: item.date,
      type: item.type,
      duration: item.duration
    };
    return DatabaseService.requireStore().insert('training_records', values);
  }

  static async updateTrainingRecord(item: TrainingRecord): Promise<void> {
    if (item.id === undefined) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      date: item.date,
      type: item.type,
      duration: item.duration
    };
    await DatabaseService.requireStore().update(values, DatabaseService.predicates('training_records', item.id));
  }

  static async deleteTrainingRecord(id: number): Promise<void> {
    await DatabaseService.requireStore().delete(DatabaseService.predicates('training_records', id));
  }

  static async getAllExamScores(): Promise<ExamScore[]> {
    const result: relationalStore.ResultSet = await DatabaseService.requireStore()
      .query(new relationalStore.RdbPredicates('exam_scores').orderByAsc('id'));
    const items: ExamScore[] = [];
    try {
      while (result.goToNextRow()) {
        items.push({
          id: result.getLong(result.getColumnIndex('id')),
          subject: result.getString(result.getColumnIndex('subject')),
          score: result.getDouble(result.getColumnIndex('score')),
          fullScore: result.getDouble(result.getColumnIndex('fullScore'))
        });
      }
    } finally {
      result.close();
    }
    return items;
  }

  static async addExamScore(item: ExamScore): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      subject: item.subject,
      score: item.score,
      fullScore: item.fullScore
    };
    return DatabaseService.requireStore().insert('exam_scores', values);
  }

  static async updateExamScore(item: ExamScore): Promise<void> {
    if (item.id === undefined) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      subject: item.subject,
      score: item.score,
      fullScore: item.fullScore
    };
    await DatabaseService.requireStore().update(values, DatabaseService.predicates('exam_scores', item.id));
  }

  static async deleteExamScore(id: number): Promise<void> {
    await DatabaseService.requireStore().delete(DatabaseService.predicates('exam_scores', id));
  }

  static async getAllDailyQuotes(): Promise<DailyQuote[]> {
    const result: relationalStore.ResultSet = await DatabaseService.requireStore()
      .query(new relationalStore.RdbPredicates('daily_quotes').orderByAsc('id'));
    const items: DailyQuote[] = [];
    try {
      while (result.goToNextRow()) {
        items.push({
          id: result.getLong(result.getColumnIndex('id')),
          content: result.getString(result.getColumnIndex('content')),
          category: result.getString(result.getColumnIndex('category')),
          used: result.getLong(result.getColumnIndex('used')) === 1,
          date: result.getString(result.getColumnIndex('date'))
        });
      }
    } finally {
      result.close();
    }
    return items;
  }

  static async addDailyQuote(item: DailyQuote): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      content: item.content,
      category: item.category,
      used: item.used ? 1 : 0,
      date: item.date === undefined ? '' : item.date
    };
    return DatabaseService.requireStore().insert('daily_quotes', values);
  }

  static async updateDailyQuote(item: DailyQuote): Promise<void> {
    if (item.id === undefined) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      content: item.content,
      category: item.category,
      used: item.used ? 1 : 0,
      date: item.date === undefined ? '' : item.date
    };
    await DatabaseService.requireStore().update(values, DatabaseService.predicates('daily_quotes', item.id));
  }

  static async deleteDailyQuote(id: number): Promise<void> {
    await DatabaseService.requireStore().delete(DatabaseService.predicates('daily_quotes', id));
  }

  static async getAllUserProfiles(): Promise<UserProfile[]> {
    const result: relationalStore.ResultSet = await DatabaseService.requireStore()
      .query(new relationalStore.RdbPredicates('user_profile').orderByAsc('id'));
    const items: UserProfile[] = [];
    try {
      while (result.goToNextRow()) {
        items.push({
          id: result.getLong(result.getColumnIndex('id')),
          nickname: result.getString(result.getColumnIndex('nickname')),
          grade: result.getString(result.getColumnIndex('grade')),
          school: result.getString(result.getColumnIndex('school'))
        });
      }
    } finally {
      result.close();
    }
    return items;
  }

  static async addUserProfile(item: UserProfile): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      nickname: item.nickname,
      grade: item.grade,
      school: item.school
    };
    return DatabaseService.requireStore().insert('user_profile', values);
  }

  static async updateUserProfile(item: UserProfile): Promise<void> {
    if (item.id === undefined) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      nickname: item.nickname,
      grade: item.grade,
      school: item.school
    };
    await DatabaseService.requireStore().update(values, DatabaseService.predicates('user_profile', item.id));
  }

  static async deleteUserProfile(id: number): Promise<void> {
    await DatabaseService.requireStore().delete(DatabaseService.predicates('user_profile', id));
  }

  static async getAllAffirmations(): Promise<Affirmation[]> {
    const result: relationalStore.ResultSet = await DatabaseService.requireStore()
      .query(new relationalStore.RdbPredicates('affirmations').orderByDesc('id'));
    const items: Affirmation[] = [];
    try {
      while (result.goToNextRow()) {
        items.push({
          id: result.getLong(result.getColumnIndex('id')),
          text: result.getString(result.getColumnIndex('text')),
          originalText: result.getString(result.getColumnIndex('originalText')),
          filePath: result.getString(result.getColumnIndex('filePath')),
          duration: result.getLong(result.getColumnIndex('duration')),
          createdAt: result.getString(result.getColumnIndex('createdAt'))
        });
      }
    } finally {
      result.close();
    }
    return items;
  }

  static async addAffirmation(item: Affirmation): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      text: item.text,
      originalText: item.originalText,
      filePath: item.filePath,
      duration: item.duration,
      createdAt: item.createdAt
    };
    return DatabaseService.requireStore().insert('affirmations', values);
  }

  static async updateAffirmation(item: Affirmation): Promise<void> {
    if (item.id === undefined) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      text: item.text,
      originalText: item.originalText,
      filePath: item.filePath,
      duration: item.duration,
      createdAt: item.createdAt
    };
    await DatabaseService.requireStore().update(values, DatabaseService.predicates('affirmations', item.id));
  }

  static async deleteAffirmation(id: number): Promise<void> {
    await DatabaseService.requireStore().delete(DatabaseService.predicates('affirmations', id));
  }

  static async getAllThoughtChallenges(): Promise<ThoughtChallenge[]> {
    const result: relationalStore.ResultSet = await DatabaseService.requireStore()
      .query(new relationalStore.RdbPredicates('thought_challenges').orderByDesc('id'));
    const items: ThoughtChallenge[] = [];
    try {
      while (result.goToNextRow()) {
        items.push({
          id: result.getLong(result.getColumnIndex('id')),
          negativeThought: result.getString(result.getColumnIndex('negativeThought')),
          alternativeThought: result.getString(result.getColumnIndex('alternativeThought')),
          distortionType: result.getString(result.getColumnIndex('distortionType')),
          createdAt: result.getString(result.getColumnIndex('createdAt'))
        });
      }
    } finally {
      result.close();
    }
    return items;
  }

  static async addThoughtChallenge(item: ThoughtChallenge): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      negativeThought: item.negativeThought,
      alternativeThought: item.alternativeThought,
      distortionType: item.distortionType,
      createdAt: item.createdAt
    };
    return DatabaseService.requireStore().insert('thought_challenges', values);
  }

  static async updateThoughtChallenge(item: ThoughtChallenge): Promise<void> {
    if (item.id === undefined) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      negativeThought: item.negativeThought,
      alternativeThought: item.alternativeThought,
      distortionType: item.distortionType,
      createdAt: item.createdAt
    };
    await DatabaseService.requireStore().update(values, DatabaseService.predicates('thought_challenges', item.id));
  }

  static async deleteThoughtChallenge(id: number): Promise<void> {
    await DatabaseService.requireStore().delete(DatabaseService.predicates('thought_challenges', id));
  }

  static async getAllVideoShares(): Promise<VideoShare[]> {
    const result: relationalStore.ResultSet = await DatabaseService.requireStore()
      .query(new relationalStore.RdbPredicates('video_shares').orderByDesc('likes'));
    const items: VideoShare[] = [];
    try {
      while (result.goToNextRow()) {
        items.push({
          id: result.getLong(result.getColumnIndex('id')),
          bvid: result.getString(result.getColumnIndex('bvid')),
          coverUrl: result.getString(result.getColumnIndex('coverUrl')),
          title: result.getString(result.getColumnIndex('title')),
          shareReason: result.getString(result.getColumnIndex('shareReason')),
          sharer: result.getString(result.getColumnIndex('sharer')),
          likes: result.getLong(result.getColumnIndex('likes')),
          category: result.getString(result.getColumnIndex('category')),
          createdAt: result.getString(result.getColumnIndex('createdAt'))
        });
      }
    } finally {
      result.close();
    }
    return items;
  }

  static async addVideoShare(item: VideoShare): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      bvid: item.bvid,
      coverUrl: item.coverUrl,
      title: item.title,
      shareReason: item.shareReason,
      sharer: item.sharer,
      likes: item.likes,
      category: item.category,
      createdAt: item.createdAt
    };
    return DatabaseService.requireStore().insert('video_shares', values);
  }

  static async updateVideoShare(item: VideoShare): Promise<void> {
    if (item.id === undefined) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      bvid: item.bvid,
      coverUrl: item.coverUrl,
      title: item.title,
      shareReason: item.shareReason,
      sharer: item.sharer,
      likes: item.likes,
      category: item.category,
      createdAt: item.createdAt
    };
    await DatabaseService.requireStore().update(values, DatabaseService.predicates('video_shares', item.id));
  }

  static async deleteVideoShare(id: number): Promise<void> {
    await DatabaseService.requireStore().delete(DatabaseService.predicates('video_shares', id));
  }

  static async getAllAppUsage(): Promise<AppUsage[]> {
    const result: relationalStore.ResultSet = await DatabaseService.requireStore()
      .query(new relationalStore.RdbPredicates('app_usage').orderByDesc('date'));
    const items: AppUsage[] = [];
    try {
      while (result.goToNextRow()) {
        items.push({
          id: result.getLong(result.getColumnIndex('id')),
          date: result.getString(result.getColumnIndex('date')),
          consecutiveDays: result.getLong(result.getColumnIndex('consecutiveDays'))
        });
      }
    } finally {
      result.close();
    }
    return items;
  }

  static async addAppUsage(item: AppUsage): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      date: item.date,
      consecutiveDays: item.consecutiveDays
    };
    return DatabaseService.requireStore().insert('app_usage', values);
  }

  static async updateAppUsage(item: AppUsage): Promise<void> {
    if (item.id === undefined) {
      return;
    }
    const values: relationalStore.ValuesBucket = {
      date: item.date,
      consecutiveDays: item.consecutiveDays
    };
    await DatabaseService.requireStore().update(values, DatabaseService.predicates('app_usage', item.id));
  }

  static async deleteAppUsage(id: number): Promise<void> {
    await DatabaseService.requireStore().delete(DatabaseService.predicates('app_usage', id));
  }
}
