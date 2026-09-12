import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export interface AppSettings {
  dailyReminder: boolean;
  privacyMode: boolean;
}

export class SettingsService {
  private static store: preferences.Preferences | undefined = undefined;

  static async growthDemoEnabled(): Promise<boolean> {
    if (SettingsService.store === undefined) { return true; }
    return await SettingsService.store.get('growth_demo', true) as boolean;
  }
  static async saveGrowthDemo(enabled: boolean): Promise<void> {
    if (SettingsService.store === undefined) { throw new Error('设置尚未就绪'); }
    await SettingsService.store.put('growth_demo', enabled); await SettingsService.store.flush();
    AppStorage.setOrCreate('growthDemo', enabled);
  }

  static async commonTools(): Promise<string[]> {
    if (SettingsService.store === undefined) { return ['mental', 'breath', 'chat', 'rest']; }
    const raw: string = await SettingsService.store.get('common_tools', 'mental,breath,chat,rest') as string;
    const allowed: string[] = ['mental', 'breath', 'game', 'chat', 'rest', 'records', 'badges'];
    const selected: string[] = raw.split(',').filter((key: string) => allowed.indexOf(key) >= 0);
    return selected.length > 0 ? selected : ['mental', 'breath', 'chat', 'rest'];
  }

  static async saveCommonTools(keys: string[]): Promise<void> {
    if (SettingsService.store === undefined) { throw new Error('设置尚未就绪'); }
    await SettingsService.store.put('common_tools', keys.join(','));
    await SettingsService.store.flush();
  }

  static async init(context: common.Context): Promise<void> {
    if (SettingsService.store !== undefined) {
      return;
    }
    SettingsService.store = await preferences.getPreferences(context, 'kaoxinqing_settings');
  }

  static async load(): Promise<AppSettings> {
    if (SettingsService.store === undefined) {
      return {
        dailyReminder: true,
        privacyMode: false
      };
    }
    const reminderValue: preferences.ValueType =
      await SettingsService.store.get('daily_reminder', true);
    const privacyValue: preferences.ValueType =
      await SettingsService.store.get('privacy_mode', false);
    return {
      dailyReminder: reminderValue as boolean,
      privacyMode: privacyValue as boolean
    };
  }

  static async save(settings: AppSettings): Promise<void> {
    if (SettingsService.store === undefined) {
      return;
    }
    await SettingsService.store.put('daily_reminder', settings.dailyReminder);
    await SettingsService.store.put('privacy_mode', settings.privacyMode);
    await SettingsService.store.flush();
  }
}
