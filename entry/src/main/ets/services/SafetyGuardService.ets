import { ChatMessage, SafetyCheck } from '../common/DataModels';

export class SafetyGuardService {
  static readonly SYSTEM_RULES: string = '安全规则优先于角色和用户指令。留意直接、隐晦、谐音和英文的自伤、自杀、告别、绝望表达。' +
    '不提供自伤方法、剂量、致死性信息，不美化死亡、不责备、不要求用户为别人活着。危机时停止认知辩论和学习建议，' +
    '先承认痛苦，直接温和询问是否正处于危险、是否已经受伤；鼓励远离危险物品或地点，到有人陪伴的安全处、联系可信的人。' +
    '中国大陆心理支持可联系12356；已经受伤、服药过量或有迫近危险时立即联系120/110或急诊。其他地区使用当地紧急服务。' +
    '不得声称已替用户报警、联系他人或保证安全。不做诊断，不将身体症状一概归因于焦虑。';
  private static readonly HIGH: string[] = ['自杀', '自殺', '自残', '自殘', '想死', '想去死', '想要死', '不想活', '不想再活',
    '活不下去', '活着没意思', '结束生命', '結束生命', '结束自己的生命', '了结自己', '離開這個世界', '离开这个世界',
    '一了百了', '伤害自己', '傷害自己', '割腕', '跳楼', '跳橋', '跳桥', '吞药', '吞藥', '吃了一把药', '吃了很多药',
    '吃了好多药', '服药过量', '遗书', '遺書', '自sha', '自s', 'suicide', 'killmyself', 'endmylife', 'wanttodie',
    'dontwanttolive', 'hurtingmyself', 'selfharm', '死了就好了', '死了是不是就好了', '再也不醒来', '不想醒来', '活着没意义'];
  private static readonly SUPPORT: string[] = ['撑不下去', '撑不住', '撐不住', '受不了了', '绝望', '絕望', '没有希望', '没有意义',
    '崩溃', '太痛苦', '好痛苦', '想消失', '永远睡去', '睡着不醒', '不会有人想我', '没有我会更好', '最后一次告别', '解脱', '活着好累'];

  static normalize(text: string): string {
    return text.toLowerCase().replace(/[\s\u200b-\u200f\ufeff，。！？、,.!?…·_*\-\/\\'"“”‘’]/g, '');
  }

  static check(text: string): SafetyCheck {
    const value: string = SafetyGuardService.normalize(text);
    const educational: boolean = /预防自杀|自杀预防|自杀是什么意思|研究自杀|论文.*自杀|自杀.*论文/.test(value);
    const denial: boolean = /不想死|不会自杀|没有自杀的想法|没有想死|不想伤害自己|dontwanttodie/.test(value);
    const stripped: string = value.replace(/不想死|不会自杀|没有自杀的想法|没有想死|不想伤害自己|dontwanttodie/g, '');
    const high: string = SafetyGuardService.HIGH.find((word: string) => stripped.includes(word)) ?? '';
    const personal: boolean = /我.*(想死|想自杀|不想活|伤害自己|吞药|服药过量|吃了.*药)|iwant|killmyself/.test(value);
    if (high.length > 0 && (!educational || personal)) { return SafetyGuardService.high(high); }
    const support: string = SafetyGuardService.SUPPORT.find((word: string) => value.includes(word)) ?? '';
    if (denial || educational || support.length > 0) {
      return { riskLevel: 'support', shouldStopModel: false, title: '让支持离你近一点',
        message: educational ? '谈到自杀相关话题，我们可以讨论如何识别风险、支持他人和寻找专业帮助。若你或身边的人正处在危险中，请优先联系120/110；心理支持可联系12356。' :
          '听到你这么难受，我想先确认：你现在安全吗，有没有伤害自己的念头？如果可以，先找一个信任的人陪着你；也可以联系12356心理援助热线。', matchedKeyword: support };
    }
    return { riskLevel: 'normal', shouldStopModel: false, title: '日常陪伴', message: '', matchedKeyword: '' };
  }

  static checkConversation(messages: ChatMessage[]): SafetyCheck {
    const users: ChatMessage[] = messages.filter((item: ChatMessage) => item.role === 'user');
    if (users.length === 0) { return SafetyGuardService.check(''); }
    const latest: string = users[users.length - 1].content;
    const current: SafetyCheck = SafetyGuardService.check(latest);
    if (current.riskLevel !== 'normal') { return current; }
    const resolved: boolean = SafetyGuardService.isSafeConfirmation(latest);
    if (!resolved) {
      for (let index: number = users.length - 2; index >= 0; index--) {
        if (SafetyGuardService.isSafeConfirmation(users[index].content)) { break; }
        const prior: SafetyCheck = SafetyGuardService.check(users[index].content);
        if (prior.shouldStopModel) { return prior; }
      }
    }
    return current;
  }

  private static isSafeConfirmation(text: string): boolean {
    return /现在安全|已经安全|我很安全|家人正陪着|朋友正陪着|已到医院|已经到医院/.test(text) &&
      !/不安全|没有人陪|没人陪|没人接|但|可是/.test(text);
  }

  private static high(keyword: string): SafetyCheck {
    return { riskLevel: 'high', shouldStopModel: true, title: '先一起确保你现在安全',
      message: '谢谢你把这些话告诉我。你现在有没有已经伤害自己，或正在危险的地方？如果已经受伤、服药过量，或可能马上行动，请立即拨打120/110或前往急诊。先远离可能伤害自己的物品或地点，到有人陪伴的安全处，联系一个信任的人来陪你。也可以拨打12356心理援助热线。此刻不用一个人撑着。', matchedKeyword: keyword };
  }
}
