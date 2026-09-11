// 考心晴 - 分布式数据管理服务
// EXPORTS: DistributeService.ets → DistributeService

import { distributedKVStore, preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';

const STORE_ID: string = 'exam_anxiety_kv';
const LOCAL_STORE_ID: string = 'exam_anxiety_local';
const BUNDLE_NAME: string = 'com.example.kaoxinqing';

export class DistributeService {
  private kvManager: distributedKVStore.KVManager | undefined = undefined;
  private kvStore: distributedKVStore.SingleKVStore | undefined = undefined;
  private localStore: preferences.Preferences | undefined = undefined;
  private changeCallback: ((key: string, value: string) => void) | undefined = undefined;

  async init(context: Context): Promise<void> {
    try {
      this.localStore = await preferences.getPreferences(context, LOCAL_STORE_ID);
    } catch (err) {
      console.error('Local preferences init failed');
    }

    try {
      const kvManagerConfig: distributedKVStore.KVManagerConfig = {
        context: context,
        bundleName: BUNDLE_NAME
      };
      this.kvManager = distributedKVStore.createKVManager(kvManagerConfig);

      const options: distributedKVStore.Options = {
        createIfMissing: true,
        encrypt: true,
        backup: true,
        autoSync: true,
        kvStoreType: distributedKVStore.KVStoreType.SINGLE_VERSION,
        securityLevel: distributedKVStore.SecurityLevel.S2
      };

      this.kvStore = await this.kvManager.getKVStore(STORE_ID, options) as distributedKVStore.SingleKVStore;

      // 注册数据变更监听
      this.kvStore.on('dataChange', distributedKVStore.SubscribeType.SUBSCRIBE_TYPE_ALL,
        (data: distributedKVStore.ChangeNotification) => {
          const entries: distributedKVStore.Entry[] = data.updateEntries;
          for (let i = 0; i < entries.length; i++) {
            const entry: distributedKVStore.Entry = entries[i];
            const key: string = entry.key;
            const val: distributedKVStore.Value = entry.value;
            const value: string = val.value as string;
            if (this.changeCallback !== undefined) {
              this.changeCallback(key, value);
            }
          }
        });
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error(`DistributeService init failed: ${error.code}, ${error.message}`);
    }
  }

  async put(key: string, value: string): Promise<void> {
    await this.putLocal(key, value);
    if (this.kvStore !== undefined) {
      try {
        await this.kvStore.put(key, value);
      } catch (err) {
        const error: BusinessError = err as BusinessError;
        console.error(`Distributed put failed: ${error.code}`);
      }
    }
  }

  async putLocal(key: string, value: string): Promise<void> {
    if (this.localStore === undefined) {
      return;
    }
    try {
      await this.localStore.put(key, value);
      await this.localStore.flush();
    } catch (err) {
      console.error(`Local put failed: ${key}`);
    }
  }

  async getLocal(key: string): Promise<string> {
    if (this.localStore === undefined) {
      return '';
    }
    try {
      const value: preferences.ValueType = await this.localStore.get(key, '');
      return typeof value === 'string' ? value : String(value);
    } catch (err) {
      return '';
    }
  }

  async get(key: string): Promise<string> {
    if (this.kvStore !== undefined) {
      try {
        const val: string | number | boolean | Uint8Array = await this.kvStore.get(key);
        if (typeof val === 'string') {
          return val;
        }
        return String(val);
      } catch (err) {
        // 分布式数据不存在时回退到本地偏好存储。
      }
    }
    return await this.getLocal(key);
  }

  onDataChange(callback: (key: string, value: string) => void): void {
    this.changeCallback = callback;
  }

  async getContinuationState(): Promise<Record<string, string>> {
    const state: Record<string, string> = {};
    state['currentAssessment'] = await this.get('currentAssessment');
    state['pressureLevel'] = await this.get('pressureLevel');
    state['studyProgress'] = await this.get('studyProgress');
    return state;
  }
}
