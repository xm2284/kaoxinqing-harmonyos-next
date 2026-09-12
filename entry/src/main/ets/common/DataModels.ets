export interface ExamInfo {
  id?: number;
  name: string;
  date: string;
  subjects: string[];
  important?: boolean;
  createdAt?: string;
}

export interface StudyTask {
  id?: number;
  title: string;
  completed: boolean;
  date: string;
  important?: boolean;
}

export interface AssessmentRecord {
  id?: number;
  date: string;
  type: string;
  answers: number[];
  totalScore: number;
  stressLevel: number;
}

export interface ChatMessage {
  id?: number;
  role: string;
  content: string;
  timestamp?: string;
}

export interface TrainingRecord {
  id?: number;
  date: string;
  type: string;
  duration: number;
}

/** 一次日常心理状态记录。分数越高表示当下感受越舒展。 */
export interface MentalHealthRecord {
  id?: number;
  recordedAt: string;
  moodScore: number;
  moodLabel: string;
  emotions: string[];
  factors: string[];
  note: string;
  source: string;
}

export interface ExamScore {
  id?: number;
  subject: string;
  score: number;
  fullScore: number;
}

export interface DailyQuote {
  id?: number;
  content: string;
  category: string;
  used: boolean;
  date?: string;
}

export interface CardDrawRecord {
  id?: number;
  content: string;
  category: string;
  drawnAt: string;
}

export interface FeedbackRecord {
  id?: number;
  category: string;
  content: string;
  createdAt: string;
}

export interface UserProfile {
  id?: number;
  nickname: string;
  grade: string;
  school: string;
  avatarPath?: string;
}

export interface GrowthEntry {
  id?: number;
  date: string;
  situation: string;
  automaticThought: string;
  distortionType: string;
  alternativeThought: string;
}

export interface Affirmation {
  id?: number;
  text: string;
  originalText: string;
  filePath: string;
  duration: number;
  createdAt: string;
}

export interface ThoughtChallenge {
  id?: number;
  negativeThought: string;
  alternativeThought: string;
  distortionType: string;
  createdAt: string;
}

export interface VideoShare {
  duration?: number;
  views?: number;
  author?: string;
  id?: number;
  bvid: string;
  coverUrl: string;
  title: string;
  shareReason: string;
  sharer: string;
  likes: number;
  category: string;
  createdAt: string;
}

export interface AppUsage {
  id?: number;
  date: string;
  consecutiveDays: number;
}

export interface SafetyCheck {
  riskLevel: string;
  shouldStopModel: boolean;
  title: string;
  message: string;
  matchedKeyword: string;
}

export interface AgentInsight {
  emotion: string;
  need: string;
  distortion: string;
  question: string;
  action: string;
  route: string;
  safetyLevel: string;
  summary: string;
}

export interface CopingRecommendation {
  title: string;
  subtitle: string;
  actionLabel: string;
  route: string;
  reason: string;
  assetName: string;
}

export interface BreathingMode {
  id: string;
  name: string;
  description: string;
  inhaleSeconds: number;
  holdSeconds: number;
  exhaleSeconds: number;
  rounds: number;
}

export interface DistortionItem {
  name: string;
  description: string;
  example: string;
}

export interface QuoteSeed {
  content: string;
  category: string;
}

export enum StressLevel {
  LOW = '低风险',
  MID_LOW = '中低风险',
  MID_HIGH = '中高风险',
  HIGH = '高风险'
}

export class AppConstants {
  static readonly APP_NAME: string = '考心晴';
  static readonly TEAM_NAME: string = '无忧队';
  static readonly SLOGAN: string = '用科学方法，让考试心情放晴';

  static readonly COLOR_PRIMARY: string = '#007DFF';
  static readonly COLOR_SECONDARY: string = '#4A90D9';
  static readonly COLOR_BACKGROUND: string = '#F0F5FF';
  static readonly COLOR_CARD: string = '#F2FFFFFF';
  static readonly COLOR_CARD_BORDER: string = '#66FFFFFF';
  static readonly COLOR_TEXT_PRIMARY: string = '#1A1A2E';
  static readonly COLOR_TEXT_SECONDARY: string = '#555666';
  static readonly COLOR_TEXT_TERTIARY: string = '#8899AA';
  static readonly COLOR_DIVIDER: string = '#1A8899AA';
  static readonly COLOR_WHITE: string = '#FFFFFF';
  static readonly COLOR_TEXT_WHITE: string = '#FFFFFF';
  static readonly COLOR_COACH: string = '#007DFF';
  static readonly COLOR_ACCENT: string = '#FF9500';
  static readonly COLOR_SURFACE_BLUE: string = '#E8F2FF';
  static readonly COLOR_SURFACE_GREEN: string = '#E8F8F2';
  static readonly COLOR_STRESS_LOW: string = '#34C759';
  static readonly COLOR_STRESS_MID_LOW: string = '#FFB020';
  static readonly COLOR_STRESS_MID_HIGH: string = '#FF9500';
  static readonly COLOR_STRESS_HIGH: string = '#FF2D55';
  static readonly COLOR_DANGER: string = '#FF3B30';
  static readonly COLOR_DEEP_BLUE: string = '#17345F';

  static readonly FONT_HERO: number = 28;
  static readonly FONT_TITLE: number = 22;
  static readonly FONT_SECTION: number = 18;
  static readonly FONT_BODY: number = 15;
  static readonly FONT_CAPTION: number = 13;
  static readonly FONT_SMALL: number = 11;
  static readonly RADIUS_CARD: number = 20;
  static readonly RADIUS_BUTTON: number = 16;
  static readonly RADIUS_TAG: number = 10;
  static readonly PADDING_PAGE: number = 16;
  static readonly PADDING_CARD: number = 16;
  static readonly SPACE_CARD: number = 12;

  static readonly API_URL: string = 'https://api.deepseek.com/chat/completions';
  static readonly API_MODEL: string = 'deepseek-chat';
  static readonly API_TEMPERATURE: number = 0.7;
  static readonly API_MAX_TOKENS: number = 500;
  static readonly API_CONNECT_TIMEOUT: number = 8000;
  static readonly API_READ_TIMEOUT: number = 15000;
  static readonly API_TIMEOUT: number = 30000;
  static readonly API_KEY: string = '';

  static readonly SYSTEM_PROMPT: string =
    '你是考心晴的AI认知调节助手小晴，面向大学生。核心策略：' +
    '第一，使用CBT苏格拉底式提问，引导识别灾难化、过度概括、非黑即白、个人化等认知扭曲；' +
    '第二，当用户提到心跳快、手抖等反应时，帮助其把身体反应重评为正在为挑战做准备；' +
    '第三，引导用户发现优势，形成简短、可信的积极自我陈述。' +
    '先共情倾听，再温和提问，最后帮助形成可执行的平衡思维。' +
    '用朋友般温暖的语气，每次回复3到5句中文，始终说明自己是AI助手。' +
    '若出现危机信号，立即停止常规对话并引导至专业帮助。';

  static readonly CRISIS_PATTERN: string =
    '自杀|想死|活不下去|结束生命|不想活了|没有希望了|没意思|撑不下去|太累了|' +
    '受不了了|不如死了|消失|离开这个世界|坚持不住了|好痛苦|解脱|一了百了|' +
    '不想坚持了|绝望|没有意义';

  static readonly HOTLINE_BEIJING: string = '010-82951332';
  static readonly HOTLINE_NATIONAL: string = '400-161-9995';
  static readonly HOTLINE_YOUTH: string = '12355';

  static readonly BREATHE_INHALE_SECONDS: number = 4;
  static readonly BREATHE_HOLD_SECONDS: number = 7;
  static readonly BREATHE_EXHALE_SECONDS: number = 8;
  static readonly BREATHE_TOTAL_ROUNDS: number = 9;
  static readonly BREATHE_MIN_RADIUS: number = 30;
  static readonly BREATHE_MAX_RADIUS: number = 120;
  static readonly COLOR_BREATHE_INHALE: string = '#4A90D9';
  static readonly COLOR_BREATHE_HOLD: string = '#8A7DFF';
  static readonly COLOR_BREATHE_EXHALE: string = '#34C759';

  static readonly DISTORTION_TYPES: DistortionItem[] = [
    {
      name: '灾难化',
      description: '把一种可能性当作必然发生的最坏结果',
      example: '这次没复习完，我一定会彻底考砸'
    },
    {
      name: '过度概括',
      description: '用一次结果推断所有未来表现',
      example: '上次数学失误，我以后数学都不行'
    },
    {
      name: '非黑即白',
      description: '只看到成功或失败，忽略中间空间',
      example: '不能拿高分就等于完全失败'
    },
    {
      name: '个人化',
      description: '把并非由自己导致的事情归咎于自己',
      example: '老师今天严肃，一定是我做错了'
    }
  ];

  static readonly GAD7_QUESTIONS: string[] = [
    '感到紧张、焦虑或急切',
    '不能停止或控制担忧',
    '对各种各样的事情担忧过多',
    '很难放松下来',
    '由于不安而无法静坐',
    '变得容易烦恼或急躁',
    '感到似乎将有可怕的事情发生而害怕'
  ];

  static readonly SAS_QUESTIONS: string[] = [
    '我觉得比平常容易紧张和着急',
    '我无缘无故地感到害怕',
    '我容易心里烦乱或觉得惊恐',
    '我觉得我可能将要发疯',
    '我觉得一切都很好，也不会发生什么不幸',
    '我手脚发抖打颤',
    '我因为头痛、颈痛和背痛而苦恼',
    '我感觉容易衰弱和疲乏',
    '我觉得心平气和，并且容易安静坐着',
    '我觉得心跳得很快',
    '我因为一阵阵头晕而苦恼',
    '我有晕倒发作或觉得要晕倒似的',
    '我呼气吸气都感到很容易',
    '我手脚麻木和刺痛',
    '我因为胃痛和消化不良而苦恼',
    '我常常要小便',
    '我的手常常是干燥温暖的',
    '我脸红发热',
    '我容易入睡并且一夜睡得很好',
    '我做恶梦'
  ];

  static readonly SCALE_OPTIONS: string[] = [
    '完全不会',
    '有几天',
    '超过一半时间',
    '几乎每天'
  ];
  static readonly SAS_OPTIONS: string[] = AppConstants.SCALE_OPTIONS;
  static readonly GAD7_OPTIONS: string[] = AppConstants.SCALE_OPTIONS;

  static readonly INPUT_PLACEHOLDERS: string[] = [
    '说说让你焦虑的事？',
    '今天感觉怎么样？',
    '有什么想聊聊的？',
    '在想什么呢？',
    '我来听你说'
  ];

  static readonly LOADING_MESSAGES: string[] = [
    '小晴正在整理你的感受……',
    '深呼吸，等一下下',
    '好的回答需要一点点时间',
    '在帮你梳理思路……'
  ];

  static readonly QUOTE_SEEDS: QuoteSeed[] = [
    { content: '今天看懂的这一页，昨天的你还不会。', category: '慢慢来' },
    { content: '先把这道题做完，远处的事晚一点再想。', category: '慢慢来' },
    { content: '一页书也算数，不必等到有整块时间才开始。', category: '慢慢来' },
    { content: '卡住了就做个记号，往后还有会做的题。', category: '慢慢来' },
    { content: '今天没弄懂的，明天可以带着问题去问。', category: '慢慢来' },
    { content: '不妨先写个草稿，写得不好也能接着改。', category: '慢慢来' },
    { content: '把笔拿起来，先写下你已经知道的。', category: '慢慢来' },
    { content: '昨天绕过的难题，今天再看，也许就有了头绪。', category: '慢慢来' },
    { content: '复习到哪里，就从哪里接着走。', category: '慢慢来' },
    { content: '计划是用来帮你的，赶不上时可以重新安排。', category: '慢慢来' },
    { content: '不用一口气补上所有落下的课，先补一节。', category: '慢慢来' },
    { content: '别急着翻下一页，刚懂的地方值得停一停。', category: '慢慢来' },
    { content: '能把问题说清楚，就已经离答案近了一点。', category: '慢慢来' },
    { content: '一道错题改明白，比匆匆刷过十道更踏实。', category: '慢慢来' },
    { content: '今天有今天的进度，不必把明天也赶完。', category: '慢慢来' },
    { content: '把难题留到精神好的时候，不算逃跑。', category: '慢慢来' },
    { content: '做完一件小事，就给它认真打个勾。', category: '慢慢来' },
    { content: '慢一点没关系，路没有因为你停顿就消失。', category: '慢慢来' },
    { content: '有些知识要见上好几面，才会慢慢熟悉。', category: '慢慢来' },
    { content: '今天先到这里，书签会替你记住下一页。', category: '慢慢来' },
    { content: '窗外有风，起身去看看吧。', category: '歇一歇' },
    { content: '水凉了就换一杯，人累了就歇一会儿。', category: '歇一歇' },
    { content: '饭要好好吃，题可以吃完再想。', category: '歇一歇' },
    { content: '把肩膀放下来，你已经绷了很久。', category: '歇一歇' },
    { content: '走到楼下再回来，也算给今天换了个场景。', category: '歇一歇' },
    { content: '抬头看看天，它不会问你今天做了多少题。', category: '歇一歇' },
    { content: '困的时候睡一觉，比反复看同一行更有用。', category: '歇一歇' },
    { content: '留一点时间给喜欢的歌，不必每分钟都有用。', category: '歇一歇' },
    { content: '晚饭后的那段路，可以慢慢走。', category: '歇一歇' },
    { content: '书合上以后，你还有自己的生活。', category: '歇一歇' },
    { content: '听一首歌的工夫，先不解决任何问题。', category: '歇一歇' },
    { content: '今天的夕阳很好，不用等考完才去看。', category: '歇一歇' },
    { content: '去洗把脸，回来再决定下一件事。', category: '歇一歇' },
    { content: '给眼睛放个假，看看窗外远一点的地方。', category: '歇一歇' },
    { content: '有空和朋友吃顿饭，聊点考试以外的事。', category: '歇一歇' },
    { content: '觉得乱的时候，先把桌上的空杯子收一收。', category: '歇一歇' },
    { content: '热饭、干净的床、一个好觉，都是正经事。', category: '歇一歇' },
    { content: '休息不需要攒够了成绩再兑换。', category: '歇一歇' },
    { content: '如果今天很累，就把明早要用的书放好。', category: '歇一歇' },
    { content: '晚安。没做完的事，醒来再说。', category: '歇一歇' },
    { content: '没考好会难过，这很正常，先别忙着责怪自己。', category: '给自己' },
    { content: '别人交卷了，你仍然可以按自己的顺序写。', category: '给自己' },
    { content: '不懂就问，没人是带着所有答案进教室的。', category: '给自己' },
    { content: '你可以说“我需要帮忙”，不用等到撑不住。', category: '给自己' },
    { content: '和朋友说话时的那份耐心，也留一点给自己。', category: '给自己' },
    { content: '暂时没有答案，可以先睡个好觉。', category: '给自己' },
    { content: '偶尔状态不好，不会抹掉前面认真学过的日子。', category: '给自己' },
    { content: '这次没做好，具体是哪一步？只看那一步就好。', category: '给自己' },
    { content: '你不用把每一天都过成冲刺。', category: '给自己' },
    { content: '先别给今天下结论，它还没过完。', category: '给自己' },
    { content: '担心的事还没发生，眼前的这一餐先好好吃。', category: '给自己' },
    { content: '有人学得快，有人记得牢，各有各的长处。', category: '给自己' },
    { content: '允许自己说一句“今天有点难”。', category: '给自己' },
    { content: '有些进步很安静，只有再做一次时才看得出来。', category: '给自己' },
    { content: '认真准备过的那些晚上，不会因为一次失误就不作数。', category: '给自己' },
    { content: '不是每次努力都立刻有回音，再给自己一点时间。', category: '给自己' },
    { content: '考完以后，先给等你的人报个平安。', category: '给自己' },
    { content: '你可以期待好结果，也可以先照顾好今天。', category: '给自己' },
    { content: '考场外还有很多条路，现在先走好眼前这一条。', category: '给自己' },
    { content: '走过这段忙碌的日子，记得请自己吃点喜欢的。', category: '给自己' },
    { content: '竹杖芒鞋轻胜马，谁怕？一蓑烟雨任平生。', category: '苏轼《定风波》' },
    { content: '莫愁前路无知己，天下谁人不识君。', category: '高适《别董大》' },
    { content: '不必一下看见终点，先完成眼前这一小步。', category: '行动' },
    { content: '紧张说明你很在意，但它不等于你做不到。', category: '鼓励' },
    { content: '把担心写下来，它就从迷雾变成了问题。', category: '认知重构' },
    { content: '呼吸慢一点，让身体先回到此刻。', category: '正念' },
    { content: '今天多理解一个概念，也是在向前。', category: '行动' },
    { content: '一次模拟成绩不能定义你的全部能力。', category: '认知重构' },
    { content: '允许自己紧张，也允许自己继续作答。', category: '正念' },
    { content: '你已经在认真面对，这本身就很勇敢。', category: '鼓励' },
    { content: '复习不是证明完美，而是减少一点不确定。', category: '行动' },
    { content: '想法不是事实，它只是大脑的一种预测。', category: '认知重构' },
    { content: '先感受双脚踩在地面上的稳定。', category: '正念' },
    { content: '你可以害怕，同时仍然做重要的事。', category: '鼓励' },
    { content: '把任务缩小到十分钟，开始会更容易。', category: '行动' },
    { content: '最坏的可能性，不代表最可能的结果。', category: '认知重构' },
    { content: '注意这一口气，不急着评价自己。', category: '正念' },
    { content: '你不是分数，你是一直在成长的人。', category: '鼓励' },
    { content: '先做会做的题，掌控感会慢慢回来。', category: '行动' },
    { content: '一次失误只能说明一次，不说明永远。', category: '认知重构' },
    { content: '观察紧张，就像观察一朵经过的云。', category: '正念' },
    { content: '准备过的内容，会在需要时慢慢浮现。', category: '鼓励' },
    { content: '完成比完美更能带来真实的进步。', category: '行动' },
    { content: '问问自己：支持这个担心的证据充分吗？', category: '认知重构' },
    { content: '肩膀放松，给身体一个安全的信号。', category: '正念' },
    { content: '你可以用自己的节奏抵达目标。', category: '鼓励' },
    { content: '列出三件已完成的事，再决定下一步。', category: '行动' },
    { content: '结果有很多种，不只有成功和失败。', category: '认知重构' },
    { content: '让注意力回到眼前的一行字。', category: '正念' },
    { content: '努力不会保证完美，但会增加你的选择。', category: '鼓励' },
    { content: '先整理错题，再安排下一轮复习。', category: '行动' },
    { content: '朋友遇到同样问题时，你会怎样安慰他？', category: '认知重构' },
    { content: '听一听周围最安静的声音。', category: '正念' },
    { content: '不确定并不可怕，你正在让它变得清晰。', category: '鼓励' },
    { content: '把大目标拆成今天可以勾选的任务。', category: '行动' },
    { content: '别人复习得快，不代表你的方法无效。', category: '认知重构' },
    { content: '不追赶念头，只看它来，再看它走。', category: '正念' },
    { content: '你比焦虑告诉你的更有能力。', category: '鼓励' },
    { content: '从最容易进入状态的科目开始。', category: '行动' },
    { content: '一时想不起来，不等于从未掌握。', category: '认知重构' },
    { content: '感受呼气比吸气稍微长一点。', category: '正念' },
    { content: '可以休息，休息也是备考的一部分。', category: '鼓励' },
    { content: '为今天设置一个明确的停止时间。', category: '行动' },
    { content: '把“必须”改成“我希望”，压力会更真实。', category: '认知重构' },
    { content: '留意身体接触椅背的感觉。', category: '正念' },
    { content: '你不需要靠责备自己才能进步。', category: '鼓励' },
    { content: '用一道题检验掌握，不用想象评判自己。', category: '行动' },
    { content: '成绩是反馈，不是对人格的判决。', category: '认知重构' },
    { content: '此刻只需要处理此刻。', category: '正念' },
    { content: '每一次回到计划，都是一次成功。', category: '鼓励' },
    { content: '把手机放远二十分钟，给自己一段专注。', category: '行动' },
    { content: '没有发挥好，也仍然有调整的空间。', category: '认知重构' },
    { content: '感觉胸口起伏，不需要改变它。', category: '正念' },
    { content: '担心会来，也会像过去那样离开。', category: '鼓励' },
    { content: '睡前写下明天最重要的三件事。', category: '行动' },
    { content: '“我完了”是一种感受，不是结论。', category: '认知重构' },
    { content: '给自己十秒钟，看看周围的颜色。', category: '正念' },
    { content: '今天的你已经拥有新的经验。', category: '鼓励' },
    { content: '错题告诉你该往哪里用力。', category: '行动' },
    { content: '把一次考试放回整段人生中看。', category: '认知重构' },
    { content: '让下巴放松，舌尖轻轻离开上颚。', category: '正念' },
    { content: '你无需独自扛住所有压力。', category: '鼓励' },
    { content: '先打开资料，开始的门槛就已经降低。', category: '行动' },
    { content: '焦虑会放大风险，也会忽略你的准备。', category: '认知重构' },
    { content: '这一分钟，只和自己的呼吸待在一起。', category: '正念' },
    { content: '稳稳做完下一步，就是很好的答案。', category: '鼓励' }
  ];

  static readonly PRESET_VIDEOS: VideoShare[] = [
    {
        "bvid": "BV1GK4y1W7ek",
        "coverUrl": "https://i2.hdslb.com/bfs/archive/19e6e36752c3e4d64a8b8bac58240b2bff8bf943.jpg",
        "title": "【治愈系动画短片】:赠人玫瑰，手有余香。",
        "shareReason": "一段轻松的动画，陪你度过短暂休息。",
        "sharer": "听澜精选",
        "likes": 0,
        "category": "治愈系",
        "createdAt": "2026-09-07",
        "duration": 213,
        "views": 51977,
        "author": "动画短片精选"
    },
    {
        "bvid": "BV1iW411w7Fn",
        "coverUrl": "https://i1.hdslb.com/bfs/archive/7d0aeaf08f8f34d5d788dce35835cec1c9ace743.jpg",
        "title": "【动画短片/治愈】✿12部萌系轻松短片✿",
        "shareReason": "一段轻松的动画，陪你度过短暂休息。",
        "sharer": "听澜精选",
        "likes": 0,
        "category": "治愈系",
        "createdAt": "2026-09-07",
        "duration": 3408,
        "views": 11967,
        "author": "high起来吧喵"
    },
    {
        "bvid": "BV1oB4y1B73S",
        "coverUrl": "https://i1.hdslb.com/bfs/archive/e9cd388c69945c9fa9db385c8fcb3dfa248e208f.jpg",
        "title": "【白噪音】小院风光｜放松｜治愈｜自然｜唯美",
        "shareReason": "听一会儿自然的声音，给思绪留一点空隙。",
        "sharer": "听澜精选",
        "likes": 0,
        "category": "治愈系",
        "createdAt": "2026-09-07",
        "duration": 4312,
        "views": 13016,
        "author": "酸老倌"
    },
    {
        "bvid": "BV12r4y157pt",
        "coverUrl": "https://i0.hdslb.com/bfs/archive/f7cc629d52457b6efd1f797802939687e7c7ea1f.jpg",
        "title": "【纯海浪声-1小时实景非循环】白噪音 环境音 海浪 萤火",
        "shareReason": "听一会儿自然的声音，给思绪留一点空隙。",
        "sharer": "听澜精选",
        "likes": 0,
        "category": "治愈系",
        "createdAt": "2026-09-07",
        "duration": 3248,
        "views": 1677908,
        "author": "silent_forest"
    },
    {
        "bvid": "BV1Sh4y1d7yE",
        "coverUrl": "https://i1.hdslb.com/bfs/archive/697a2178d18777f619f592608691a52a0351cc3d.jpg",
        "title": "【4K｜白噪声】夏夜，海浪与微风，适合休闲/放松/工作/学习的背景声",
        "shareReason": "听一会儿自然的声音，给思绪留一点空隙。",
        "sharer": "听澜精选",
        "likes": 0,
        "category": "治愈系",
        "createdAt": "2026-09-07",
        "duration": 4902,
        "views": 5102,
        "author": "Its_JazZ"
    },
    {
        "bvid": "BV1so4y1C7dY",
        "coverUrl": "https://i1.hdslb.com/bfs/archive/30e72cf912cdf424eea61c2fd2c768ab88347c5b.jpg",
        "title": "【白噪音】1小时实录夏威夷海边浪声|助眠，学习，冥想，放松|4K上传",
        "shareReason": "听一会儿自然的声音，给思绪留一点空隙。",
        "sharer": "听澜精选",
        "likes": 0,
        "category": "治愈系",
        "createdAt": "2026-09-07",
        "duration": 4339,
        "views": 7807,
        "author": "FBI熙熙"
    }
];

  static getStressColor(level: number): string {
    if (level <= 3) {
      return AppConstants.COLOR_STRESS_LOW;
    }
    if (level <= 5) {
      return AppConstants.COLOR_STRESS_MID_LOW;
    }
    if (level <= 7) {
      return AppConstants.COLOR_STRESS_MID_HIGH;
    }
    return AppConstants.COLOR_STRESS_HIGH;
  }

  static getStressLabel(level: number): string {
    if (level <= 3) {
      return StressLevel.LOW;
    }
    if (level <= 5) {
      return StressLevel.MID_LOW;
    }
    if (level <= 7) {
      return StressLevel.MID_HIGH;
    }
    return StressLevel.HIGH;
  }

  static withAlpha(color: string, alpha: string): string {
    return '#' + alpha + color.substring(1);
  }
}
