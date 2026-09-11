import { CopingRecommendation } from '../common/DataModels';

export class WellnessEngine {
  static primaryRecommendation(
    pressureLevel: number,
    daysUntilExam: number,
    focusMinutes: number,
    chatCount: number,
    challengeCount: number
  ): CopingRecommendation {
    if (pressureLevel >= 7) {
      return {
        title: '先让身体稳下来',
        subtitle: '压力偏高，建议先做一轮云息呼吸。',
        actionLabel: '去呼吸',
        route: 'pages/RelaxationPage',
        reason: '高压力优先身体调节',
        assetName: 'kxq_icon_breath.png'
      };
    }
    if (focusMinutes >= 80) {
      return {
        title: '该给大脑放个短假',
        subtitle: '已经专注一段时间，休息会让下一轮更稳。',
        actionLabel: '去休息',
        route: 'pages/RestBreakPage',
        reason: '长时间学习后推荐恢复',
        assetName: 'kxq_icon_rest.png'
      };
    }
    if (daysUntilExam <= 7) {
      return {
        title: '考前先稳住节奏',
        subtitle: '考试临近，先做小清单，再处理担心。',
        actionLabel: '设计划',
        route: 'pages/CountdownSettingPage',
        reason: '考试临近推荐清单化',
        assetName: 'kxq_extra_checklist.png'
      };
    }
    if (challengeCount === 0) {
      return {
        title: '试试换个角度',
        subtitle: '把一个担心翻成更公平的想法。',
        actionLabel: '去翻牌',
        route: 'pages/GamePage',
        reason: '未做过认知重构',
        assetName: 'kxq_icon_game.png'
      };
    }
    if (chatCount === 0) {
      return {
        title: '把担心说出来',
        subtitle: '小晴会先听见你，再一起找下一步。',
        actionLabel: '去聊聊',
        route: 'coach',
        reason: '还没有进行过心语对话',
        assetName: 'kxq_icon_chat.png'
      };
    }
    return {
      title: '继续稳稳推进',
      subtitle: '今天可以从一个 5 分钟小任务开始。',
      actionLabel: '开始',
      route: 'coach',
      reason: '默认轻行动建议',
      assetName: 'kxq_extra_progress_sprout.png'
    };
  }
}
