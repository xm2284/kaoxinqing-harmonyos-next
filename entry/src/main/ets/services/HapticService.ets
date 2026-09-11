import { vibrator } from '@kit.SensorServiceKit';

export class HapticService {
  static light(): void {
    vibrator.startVibration(
      {
        type: 'time',
        duration: 5
      },
      {
        usage: 'touch'
      }
    ).catch(() => {
      console.info('Light haptic unavailable');
    });
  }

  static confirm(): void {
    vibrator.startVibration(
      {
        type: 'time',
        duration: 10
      },
      {
        usage: 'notification'
      }
    ).catch(() => {
      console.info('Confirm haptic unavailable');
    });
  }
}
