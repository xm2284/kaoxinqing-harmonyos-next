import { BreathingMode } from '../common/DataModels';

export class BreathingModeService {
  static modes(): BreathingMode[] {
    return [
      {
        id: '478',
        name: '4-7-8 呼吸',
        description: '适合焦虑明显时，把呼气拉长。',
        inhaleSeconds: 4,
        holdSeconds: 7,
        exhaleSeconds: 8,
        rounds: 5
      },
      {
        id: 'box',
        name: '方块呼吸',
        description: '适合考前稳定注意力。',
        inhaleSeconds: 4,
        holdSeconds: 4,
        exhaleSeconds: 4,
        rounds: 6
      },
      {
        id: 'quick',
        name: '快速放松',
        description: '适合上考场前快速安顿身体。',
        inhaleSeconds: 3,
        holdSeconds: 2,
        exhaleSeconds: 5,
        rounds: 5
      }
    ];
  }
}
