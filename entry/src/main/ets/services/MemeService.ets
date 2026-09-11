import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export class MemeService {
  private static store: preferences.Preferences | undefined = undefined;
  private static readonly STORE_NAME: string = 'kaoxinqing_meme_preferences';

  static async init(context: common.Context): Promise<void> {
    if (MemeService.store !== undefined) {
      return;
    }
    MemeService.store = await preferences.getPreferences(context, MemeService.STORE_NAME);
  }

  static async setEnabled(enabled: boolean): Promise<void> {
    if (MemeService.store === undefined) {
      return;
    }
    await MemeService.store.put('enabled', enabled);
    await MemeService.store.flush();
  }

  static async isEnabled(): Promise<boolean> {
    if (MemeService.store === undefined) {
      return true;
    }
    const value: preferences.ValueType = await MemeService.store.get('enabled', true);
    return value as boolean;
  }

  static async shouldShow(trigger: string): Promise<boolean> {
    if (MemeService.store === undefined || !await MemeService.isEnabled()) {
      return false;
    }
    const now: number = Date.now();
    const day: string = MemeService.today();
    const triggerValue: preferences.ValueType =
      await MemeService.store.get('trigger_' + trigger, 0);
    const lastValue: preferences.ValueType =
      await MemeService.store.get('last_popup_timestamp', 0);
    const countValue: preferences.ValueType =
      await MemeService.store.get('popup_count_' + day, 0);
    const triggerTime: number = triggerValue as number;
    const lastTime: number = lastValue as number;
    const count: number = countValue as number;
    if (now - triggerTime < 300000 || now - lastTime < 10000 || count >= 8) {
      return false;
    }
    await MemeService.store.put('trigger_' + trigger, now);
    await MemeService.store.put('last_popup_timestamp', now);
    await MemeService.store.put('popup_count_' + day, count + 1);
    await MemeService.store.flush();
    return true;
  }

  static async shouldShowOnce(trigger: string): Promise<boolean> {
    if (MemeService.store === undefined || !await MemeService.isEnabled()) {
      return false;
    }
    const key: string = 'once_popup_' + trigger;
    const shownValue: preferences.ValueType = await MemeService.store.get(key, false);
    if (shownValue as boolean) {
      return false;
    }
    await MemeService.store.put(key, true);
    await MemeService.store.flush();
    return true;
  }

  static matchTopic(text: string): string {
    if (text.includes('宋浩') || text.includes('高数') || text.includes('数学')) {
      return 'songhao';
    }
    if (text.includes('挂科') || text.includes('不及格') || text.includes('完了')) {
      return 'studycat';
    }
    if (text.includes('焦虑') || text.includes('紧张') || text.includes('压力') || text.includes('烦')) {
      return 'breakdown';
    }
    return '';
  }

  static dailyAsset(): string {
    return 'daily_' + ((new Date().getDate() % 5) + 1).toString();
  }

  private static today(): string {
    const date: Date = new Date();
    const month: string = (date.getMonth() + 1).toString().padStart(2, '0');
    const day: string = date.getDate().toString().padStart(2, '0');
    return date.getFullYear().toString() + '-' + month + '-' + day;
  }
}
