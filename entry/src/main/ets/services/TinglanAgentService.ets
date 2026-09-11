import { AgentInsight, ChatMessage, SafetyCheck } from '../common/DataModels';
import { LocalReplyBank } from './LocalReplyBank';
import { SafetyGuardService } from './SafetyGuardService';

export class TinglanAgentService {
  static emptyInsight(): AgentInsight {
    return {
      emotion: '等待表达',
      need: '被看见',
      distortion: '暂未识别',
      question: '此刻最想被理解的是哪一部分？',
      action: '写下一句真实感受',
      route: 'coach',
      safetyLevel: 'normal',
      summary: '听澜会先听见情绪，再和明镜、拾光一起给出下一步。'
    };
  }

  static latestUserText(messages: ChatMessage[]): string {
    for (let index: number = messages.length - 1; index >= 0; index--) {
      if (messages[index].role === 'user') {
        return messages[index].content;
      }
    }
    return '';
  }

  static analyzeMessages(messages: ChatMessage[]): AgentInsight {
    return TinglanAgentService.analyzeText(TinglanAgentService.latestUserText(messages));
  }

  static analyzeText(text: string): AgentInsight {
    const safety: SafetyCheck = SafetyGuardService.check(text);
    const emotion: string = TinglanAgentService.detectEmotion(text);
    const need: string = TinglanAgentService.detectNeed(text);
    const distortion: string = TinglanAgentService.detectDistortion(text);
    const action: string = TinglanAgentService.suggestAction(text, emotion, distortion);
    const route: string = TinglanAgentService.suggestRoute(text, emotion, distortion);
    const question: string = TinglanAgentService.buildQuestion(distortion, emotion);
    return {
      emotion: emotion,
      need: need,
      distortion: distortion,
      question: question,
      action: action,
      route: route,
      safetyLevel: safety.riskLevel,
      summary: '听澜识别到“' + emotion + '”，明镜关注“' + distortion + '”，拾光建议“' + action + '”。'
    };
  }

  static localReply(messages: ChatMessage[]): string {
    const safety: SafetyCheck = SafetyGuardService.checkConversation(messages);
    if (safety.riskLevel !== 'normal') { return safety.message; }
    return LocalReplyBank.reply(messages);
  }

  static coordinatorSystemPrompt(insight: AgentInsight): string {
    return SafetyGuardService.SYSTEM_RULES + '你是考心晴的统筹 Agent。内部结果：' +
      '听澜识别情绪为“' + insight.emotion + '”，需要是“' + insight.need + '”；' +
      '明镜识别可能的认知模式为“' + insight.distortion + '”，建议提问“' + insight.question + '”；' +
      '拾光建议的行动是“' + insight.action + '”。' +
      '请不要暴露内部推理过程，不做诊断，不承诺治疗。最终回复 3 到 5 句中文：先共情，再指出一个可能的思维模式，提出一个温和问题，最后给一个五分钟内可执行的小步骤。';
  }

  static agentPrompt(name: string, insight: AgentInsight): string {
    if (name === 'tinglan') {
      return SafetyGuardService.SYSTEM_RULES + '你是内部协作 Agent“听澜”。只分析用户主要情绪和被理解的需要。已知本地初判：情绪=' +
        insight.emotion + '，需要=' + insight.need + '。输出 1 到 2 句内部摘要。';
    }
    if (name === 'mingjing') {
      return '你是内部协作 Agent“明镜”。用 CBT 视角识别一种可能的认知偏差，并提出一个证据检验问题。已知本地初判：' +
        insight.distortion + '。输出 1 到 2 句内部摘要。';
    }
    return '你是内部协作 Agent“拾光”。根据备考场景，只提出一个五分钟内可完成的小行动。已知本地建议：' +
      insight.action + '。输出 1 句话。';
  }

  private static detectEmotion(text: string): string {
    if (text.includes('睡不着') || text.includes('失眠') || text.includes('累') || text.includes('疲惫')) {
      return '疲惫';
    }
    if (text.includes('怕') || text.includes('担心') || text.includes('紧张') || text.includes('焦虑')) {
      return '焦虑';
    }
    if (text.includes('烦') || text.includes('崩溃') || text.includes('受不了')) {
      return '烦躁';
    }
    if (text.includes('内疚') || text.includes('后悔') || text.includes('自责')) {
      return '自责';
    }
    if (text.includes('没进度') || text.includes('学不进去') || text.includes('不会')) {
      return '无力';
    }
    return '压力';
  }

  private static detectNeed(text: string): string {
    if (text.includes('睡') || text.includes('累')) {
      return '休息和恢复';
    }
    if (text.includes('没人') || text.includes('孤单') || text.includes('一个人')) {
      return '陪伴和连接';
    }
    if (text.includes('怎么办') || text.includes('不知道')) {
      return '清晰的下一步';
    }
    return '被理解和稳定感';
  }

  private static detectDistortion(text: string): string {
    if (text.includes('一定') || text.includes('完了') || text.includes('彻底') || text.includes('肯定')) {
      return '灾难化';
    }
    if (text.includes('永远') || text.includes('每次') || text.includes('从来') || text.includes('总是')) {
      return '过度概括';
    }
    if (text.includes('必须') || text.includes('要么') || text.includes('全都') || text.includes('一点都')) {
      return '非黑即白';
    }
    if (text.includes('别人都') || text.includes('大家都') || text.includes('只有我')) {
      return '比较放大';
    }
    if (text.includes('应该') || text.includes('不该')) {
      return '应该化';
    }
    return '自动化负面想法';
  }

  private static buildQuestion(distortion: string, emotion: string): string {
    if (distortion === '灾难化') {
      return '最坏结果一定会发生吗，还有没有更可能的中间结果？';
    }
    if (distortion === '过度概括') {
      return '这一次的困难能代表每一次都会这样吗？';
    }
    if (distortion === '非黑即白') {
      return '除了满分和失败，中间还有哪些可接受的结果？';
    }
    if (emotion === '疲惫') {
      return '现在是真的需要更用力，还是需要先恢复一点能量？';
    }
    return '支持这个担心的证据有哪些，不支持它的证据又有哪些？';
  }

  private static suggestAction(text: string, emotion: string, distortion: string): string {
    if (emotion === '疲惫' || text.includes('睡')) {
      return '给自己 20 分钟休息边界';
    }
    if (text.includes('心跳') || text.includes('手抖') || emotion === '焦虑') {
      return '先坐稳，保持自然呼吸';
    }
    if (distortion !== '自动化负面想法') {
      return '写下一个支持证据和一个反向证据';
    }
    return '把任务缩小成 5 分钟能开始的一步';
  }

  private static suggestRoute(text: string, emotion: string, distortion: string): string {
    if (emotion === '疲惫' || text.includes('睡')) {
      return 'rest';
    }
    if (emotion === '焦虑' || text.includes('心跳') || text.includes('手抖')) {
      return 'relaxation';
    }
    if (distortion !== '自动化负面想法') {
      return 'game';
    }
    return 'coach';
  }
}
