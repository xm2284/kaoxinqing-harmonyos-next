import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { http } from '@kit.NetworkKit';
import { AgentInsight, AppConstants, ChatMessage, SafetyCheck } from '../common/DataModels';
import { SafetyGuardService } from './SafetyGuardService';
import { TinglanAgentService } from './TinglanAgentService';

interface ApiMessage {
  role: string;
  content: string;
}

interface DeepSeekRequest {
  model: string;
  messages: ApiMessage[];
  temperature: number;
  max_tokens: number;
}

interface DeepSeekResponseMessage {
  role: string;
  content: string;
}

interface DeepSeekChoice {
  index: number;
  message: DeepSeekResponseMessage;
  finish_reason: string;
}

interface DeepSeekResponse {
  choices: DeepSeekChoice[];
}

export class ApiService {
  private static store: preferences.Preferences | undefined = undefined;
  private static readonly PREFERENCE_NAME: string = 'kaoxinqing_secure_settings';
  private static readonly API_KEY_NAME: string = 'deepseek_api_key';

  static async init(context: common.Context): Promise<void> {
    if (ApiService.store !== undefined) {
      return;
    }
    ApiService.store = await preferences.getPreferences(context, ApiService.PREFERENCE_NAME);
  }

  static async getApiKey(): Promise<string> {
    if (ApiService.store === undefined) {
      return '';
    }
    const value: preferences.ValueType = await ApiService.store.get(ApiService.API_KEY_NAME, '');
    return value as string;
  }

  static async saveApiKey(apiKey: string): Promise<void> {
    if (ApiService.store === undefined) {
      throw new Error('设置服务尚未初始化');
    }
    await ApiService.store.put(ApiService.API_KEY_NAME, apiKey.trim());
    await ApiService.store.flush();
  }

  static checkCrisis(text: string): boolean {
    return SafetyGuardService.check(text).shouldStopModel;
  }

  static safetyReply(text: string): string {
    const safety: SafetyCheck = SafetyGuardService.check(text);
    return safety.message;
  }

  static async cognitiveCoachRequest(messages: ChatMessage[]): Promise<string> {
    const latestText: string = TinglanAgentService.latestUserText(messages);
    const safety: SafetyCheck = SafetyGuardService.checkConversation(messages);
    if (safety.shouldStopModel) {
      return safety.message;
    }
    const insight: AgentInsight = TinglanAgentService.analyzeText(latestText);
    const apiKey: string = await ApiService.getApiKey();
    if (apiKey.length === 0) {
      return TinglanAgentService.localReply(messages);
    }

    const agentTasks: Promise<string>[] = [
      ApiService.requestAgent(
        messages,
        apiKey,
        TinglanAgentService.agentPrompt('tinglan', insight),
        120
      ),
      ApiService.requestAgent(
        messages,
        apiKey,
        TinglanAgentService.agentPrompt('mingjing', insight),
        120
      ),
      ApiService.requestAgent(
        messages,
        apiKey,
        TinglanAgentService.agentPrompt('shiguang', insight),
        100
      )
    ];
    const insights: string[] = await Promise.all(agentTasks);
    if (insights[0].trim().length === 0 && insights[1].trim().length === 0 &&
      insights[2].trim().length === 0) {
      return TinglanAgentService.localReply(messages);
    }
    const coordinatorMessages: ChatMessage[] = messages.slice();
    coordinatorMessages.push({
      role: 'system',
      content: '内部协作结果：听澜：' + insights[0] +
        '；明镜：' + insights[1] + '；拾光：' + insights[2]
    });
    const coordinatorPrompt: string = AppConstants.SYSTEM_PROMPT +
      TinglanAgentService.coordinatorSystemPrompt(insight);
    const result: string = await ApiService.requestAgent(
      coordinatorMessages,
      apiKey,
      coordinatorPrompt,
      AppConstants.API_MAX_TOKENS
    );
    if (result.trim().length > 0) {
      return result;
    }
    return TinglanAgentService.localReply(messages);
  }

  static async polishAffirmation(text: string): Promise<string> {
    const safety: SafetyCheck = SafetyGuardService.check(text);
    if (safety.riskLevel !== 'normal') { return safety.message; }
    const apiKey: string = await ApiService.getApiKey();
    if (apiKey.length === 0) {
      return text;
    }
    const prompt: ChatMessage[] = [
      {
        role: 'user',
        content: text
      }
    ];
    const result: string = await ApiService.requestAgent(
      prompt,
      apiKey,
      '请将用户的自我鼓励语润色得更积极有力，保留原意，控制在50字以内。只输出润色后的句子。',
      100
    );
    return result.trim().length > 0 ? result.trim() : text;
  }

  static async challengeThought(negativeThought: string, round: number, answers: string[]): Promise<string> {
    const safety: SafetyCheck = SafetyGuardService.check(negativeThought + answers.join('。'));
    if (safety.riskLevel !== 'normal') { return safety.message; }
    const roundPrompt: string[] = [
      '用户刚完成证据检验。请先用一句话反馈，再引导换位思考：如果最好的朋友这样想，会怎样回应。只提出一个问题。',
      '用户刚完成换位思考。请先用一句话反馈，再引导他结合已有证据形成一句客观、可信、可行动的平衡思维。只提出一个问题。',
      '请结合三轮回答，帮助形成一句客观、可信、可行动的平衡思维。'
    ];
    const safeRound: number = Math.max(0, Math.min(2, round - 1));
    const apiKey: string = await ApiService.getApiKey();
    if (apiKey.length === 0) {
      if (safeRound === 0) {
        return '你已经开始区分事实和担心了。接下来想一想：如果最好的朋友有同样的担忧，你会怎样对他说？';
      }
      return '你对朋友的语气通常比对自己更公平。综合刚才的证据，一个既客观又能帮助你行动的新说法是什么？';
    }
    let answerContext: string = '';
    for (let index: number = 0; index < answers.length; index++) {
      answerContext += '第' + (index + 1).toString() + '轮回答：' + answers[index] + '；';
    }
    const messages: ChatMessage[] = [
      {
        role: 'system',
        content: roundPrompt[safeRound]
      },
      {
        role: 'user',
        content: '负面想法：' + negativeThought + '；' + answerContext
      }
    ];
    return ApiService.requestAgent(messages, apiKey, roundPrompt[safeRound], 160);
  }

  private static async requestAgent(
    messages: ChatMessage[],
    apiKey: string,
    systemPrompt: string,
    maxTokens: number
  ): Promise<string> {
    const requestMessages: ApiMessage[] = [];
    requestMessages.push({
      role: 'system',
      content: SafetyGuardService.SYSTEM_RULES + systemPrompt
    });
    for (let index: number = 0; index < messages.length; index++) {
      requestMessages.push({
        role: messages[index].role,
        content: messages[index].role === 'user' && SafetyGuardService.check(messages[index].content).shouldStopModel ?
          '此前表达过强烈困扰，请以支持性交流为主。' : messages[index].content
      });
    }
    const requestBody: DeepSeekRequest = {
      model: AppConstants.API_MODEL,
      messages: requestMessages,
      temperature: AppConstants.API_TEMPERATURE,
      max_tokens: maxTokens
    };
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(AppConstants.API_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + apiKey
        },
        extraData: JSON.stringify(requestBody),
        connectTimeout: AppConstants.API_CONNECT_TIMEOUT,
        readTimeout: AppConstants.API_READ_TIMEOUT
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return '';
      }
      const payload: DeepSeekResponse = JSON.parse(response.result as string) as DeepSeekResponse;
      if (payload.choices.length === 0) {
        return '';
      }
      return payload.choices[0].message.content;
    } catch (reason) {
      const error: BusinessError = reason as BusinessError;
      console.error('ApiService request failed: ' + error.code);
      return '';
    } finally {
      request.destroy();
    }
  }

}
