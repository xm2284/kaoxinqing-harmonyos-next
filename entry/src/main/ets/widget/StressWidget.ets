// 考心晴 - 元服务卡片 FormExtensionAbility
// 使用 @ohos.app.form 旧式导入避免 "can't support form application" 错误

import formInfo from '@ohos.app.form.formInfo';
import formBindingData from '@ohos.app.form.formBindingData';
import FormExtensionAbility from '@ohos.app.form.FormExtensionAbility';
import formProvider from '@ohos.app.form.formProvider';
import Want from '@ohos.app.ability.Want';
import { DistributeService } from '../services/DistributeService';

interface WidgetExamInfo {
  name: string;
  date: string;
}

export default class StressWidget extends FormExtensionAbility {
  private distributeService: DistributeService = new DistributeService();

  onAddForm(want: Want): formBindingData.FormBindingData {
    const dimension: string = want.parameters !== undefined ?
      String(want.parameters['ohos.extra.param.key.form_dimension'] ?? '2') : '2';
    const formData: Record<string, string> = {
      'examDays': '21',
      'pressureLevel': '5',
      'pressureColor': '#FFD93D',
      'pressureLabel': '中低风险',
      'taskProgress': '0.35',
      'formDimension': dimension,
      'title': '考心晴'
    };
    const formId: string = want.parameters !== undefined ?
      String(want.parameters['ohos.extra.param.key.form_identity'] ?? '') : '';
    if (formId.length > 0) {
      this.refreshFromStorage(formId);
    }
    return formBindingData.createFormBindingData(formData);
  }

  onUpdateForm(formId: string): void {
    this.refreshFromStorage(formId);
  }

  onFormEvent(formId: string, message: string): void {
    try {
      const msg: Record<string, string> = JSON.parse(message) as Record<string, string>;
      const formData: Record<string, string> = {
        'examDays': msg['examDays'] ?? '21',
        'pressureLevel': msg['pressureLevel'] ?? '5',
        'pressureColor': msg['pressureColor'] ?? '#FFD93D',
        'pressureLabel': msg['pressureLabel'] ?? '中低风险',
        'taskProgress': msg['taskProgress'] ?? '0.35',
        'formDimension': msg['formDimension'] ?? '2',
        'title': '考心晴'
      };
      const bindingData: formBindingData.FormBindingData = formBindingData.createFormBindingData(formData);
      formProvider.updateForm(formId, bindingData);
    } catch (e) {
      // parse error
    }
  }

  onRemoveForm(formId: string): void {
    // card removed
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    try {
      return formInfo.FormState.READY;
    } catch (err) {
      console.error(`onAcquireFormState error: ${JSON.stringify(err)}`);
      return formInfo.FormState.READY;
    }
  }

  private async refreshFromStorage(formId: string): Promise<void> {
    try {
      await this.distributeService.init(this.context);
      const state: Record<string, string> = await this.distributeService.getContinuationState();
      const pressure: number = parseFloat(state['pressureLevel'] ?? '3');
      const progress: number = parseFloat(state['studyProgress'] ?? '0');
      const examJson: string = await this.distributeService.get('examInfoJson');
      const level: number = isNaN(pressure) ? 3 : pressure;
      const taskProgress: number = isNaN(progress) ? 0 : progress;
      let examDays: number = 21;
      if (examJson.length > 0) {
        const exam: WidgetExamInfo = JSON.parse(examJson) as WidgetExamInfo;
        examDays = Math.max(0, Math.ceil((new Date(exam.date).getTime() - Date.now()) / 86400000));
      }
      const formData: Record<string, string> = {
        'examDays': examDays.toString(),
        'pressureLevel': level.toFixed(1),
        'pressureColor': this.getPressureColor(level),
        'pressureLabel': this.getPressureLabel(level),
        'taskProgress': taskProgress.toString(),
        'title': '考心晴'
      };
      const bindingData: formBindingData.FormBindingData = formBindingData.createFormBindingData(formData);
      await formProvider.updateForm(formId, bindingData);
    } catch (err) {
      console.info('Widget refresh uses default data');
    }
  }

  private getPressureColor(level: number): string {
    if (level <= 3) {
      return '#34C759';
    } else if (level <= 5) {
      return '#FFB020';
    } else if (level <= 7) {
      return '#FF9500';
    }
    return '#FF2D55';
  }

  private getPressureLabel(level: number): string {
    if (level <= 3) {
      return '低风险';
    } else if (level <= 5) {
      return '中低风险';
    } else if (level <= 7) {
      return '中高风险';
    }
    return '高风险';
  }
}
