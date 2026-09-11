// 考心晴 - 小艺意图共享
// 需在 AppGallery Connect 注册同名意图；未注册时安静降级。

import { insightIntent } from '@kit.IntentsKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class IntentService {
  static async shareBreathingIntent(context: common.UIAbilityContext, mode: string): Promise<void> {
    const timestamp: number = new Date().getTime();
    const intent: insightIntent.InsightIntent = {
      intentName: 'StartBreathingTraining',
      intentVersion: '1.0.0',
      identifier: `breathing_${timestamp}`,
      intentActionInfo: {
        action: 'action.kaoxinqing.breathing',
        mode: mode
      },
      intentEntityInfo: {
        entityId: mode,
        entityName: 'BreathingTraining',
        displayName: '开始呼吸训练'
      }
    };
    try {
      await insightIntent.shareIntent(context, [intent]);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.info(`InsightIntent unavailable: ${error.code}`);
    }
  }
}
