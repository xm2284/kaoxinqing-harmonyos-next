// 考心晴 - 呼吸训练实况窗
// Live View 权益未开通或设备不支持时自动降级，不影响应用内训练。

import { liveViewManager } from '@kit.LiveViewKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class LiveViewService {
  private active: boolean = false;
  private sequence: number = 0;
  private activityTitle: string;
  private eventName: string;
  private liveViewId: number;

  constructor(
    activityTitle: string = '呼吸训练',
    eventName: string = 'kaoxinqing_breathing',
    liveViewId: number = 20260726
  ) {
    this.activityTitle = activityTitle;
    this.eventName = eventName;
    this.liveViewId = liveViewId;
  }

  async start(phase: string, seconds: number): Promise<boolean> {
    try {
      const enabled: boolean = await liveViewManager.isLiveViewEnabled();
      if (!enabled) {
        return false;
      }
      this.sequence = 0;
      const result: liveViewManager.LiveViewResult =
        await liveViewManager.startLiveView(this.createLiveView(phase, seconds, false));
      this.active = result.resultCode === 0;
      return this.active;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.info(`LiveView start unavailable: ${error.code}`);
      this.active = false;
      return false;
    }
  }

  async update(phase: string, seconds: number, paused: boolean): Promise<void> {
    if (!this.active) {
      return;
    }
    try {
      this.sequence++;
      await liveViewManager.updateLiveView(this.createLiveView(phase, seconds, paused));
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.info(`LiveView update unavailable: ${error.code}`);
      this.active = false;
    }
  }

  async stop(completed: boolean, finalText: string = ''): Promise<void> {
    if (!this.active) {
      return;
    }
    try {
      this.sequence++;
      const phase: string = finalText.length > 0 ? finalText :
        completed ? this.activityTitle + '完成' : this.activityTitle + '已结束';
      await liveViewManager.stopLiveView(this.createLiveView(phase, 0, false));
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.info(`LiveView stop unavailable: ${error.code}`);
    }
    this.active = false;
  }

  isActive(): boolean {
    return this.active;
  }

  private createLiveView(phase: string, seconds: number, paused: boolean): liveViewManager.LiveView {
    const contentText: string = seconds > 0 ? phase + ' · ' + this.formatRemaining(seconds) : phase;
    const capsule: liveViewManager.TextCapsule = {
      type: liveViewManager.CapsuleType.CAPSULE_TYPE_TEXT,
      status: paused ? 1 : 0,
      title: '考心晴',
      content: contentText,
      backgroundColor: '#FF0A59F7'
    };
    return {
      id: this.liveViewId,
      event: this.eventName,
      sequence: this.sequence,
      isMute: true,
      liveViewData: {
        primary: {
          title: this.activityTitle,
          content: [
            {
              text: contentText,
              textColor: '#FF18243A'
            }
          ],
          keepTime: 0,
          aliveTime: 60
        },
        capsule: capsule
      }
    };
  }

  private formatRemaining(seconds: number): string {
    if (seconds < 60) {
      return seconds.toString() + '秒';
    }
    const minutes: string = Math.floor(seconds / 60).toString().padStart(2, '0');
    const remaining: string = (seconds % 60).toString().padStart(2, '0');
    return minutes + ':' + remaining;
  }
}
