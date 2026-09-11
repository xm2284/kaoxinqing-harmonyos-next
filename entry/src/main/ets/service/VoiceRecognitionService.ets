// 考心晴 - Core Speech Kit 实时语音输入

import { speechRecognizer } from '@kit.CoreSpeechKit';
import { audio } from '@kit.AudioKit';
import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';

export class VoiceRecognitionService {
  private engine: speechRecognizer.SpeechRecognitionEngine | undefined = undefined;
  private capturer: audio.AudioCapturer | undefined = undefined;
  private sessionId: string = '';
  private recording: boolean = false;
  private pendingAudio: Uint8Array = new Uint8Array(0);
  private audioFile: fileIo.File | undefined = undefined;
  private resultCallback: ((text: string, isFinal: boolean) => void) | undefined = undefined;
  private statusCallback: ((status: string) => void) | undefined = undefined;

  async start(context: common.UIAbilityContext,
    onResult: (text: string, isFinal: boolean) => void,
    onStatus: (status: string) => void,
    savePath: string = ''): Promise<boolean> {
    if (this.recording) {
      return true;
    }

    this.resultCallback = onResult;
    this.statusCallback = onStatus;
    const granted: boolean = await this.requestMicrophonePermission(context);
    if (!granted) {
      onStatus('未获得麦克风权限');
      return false;
    }

    try {
      this.sessionId = `kaoxinqing_${new Date().getTime()}`;
      if (savePath.length > 0) {
        this.audioFile = fileIo.openSync(
          savePath,
          fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC
        );
      }
      this.engine = await speechRecognizer.createEngine({
        language: 'zh-CN',
        online: 1
      });

      const service: VoiceRecognitionService = this;
      const listener: speechRecognizer.RecognitionListener = {
        onStart(sessionId: string, eventMessage: string): void {
          service.notifyStatus('正在聆听');
        },
        onEvent(sessionId: string, eventCode: number, eventMessage: string): void {
          if (eventCode === 3) {
            service.notifyStatus('正在识别');
          }
        },
        onResult(sessionId: string, result: speechRecognizer.SpeechRecognitionResult): void {
          if (service.resultCallback !== undefined && result.result.length > 0) {
            service.resultCallback(result.result, result.isFinal);
          }
          if (result.isLast) {
            service.recording = false;
            service.notifyStatus('识别完成');
          }
        },
        onComplete(sessionId: string, eventMessage: string): void {
          service.recording = false;
          service.notifyStatus('识别完成');
          service.release();
        },
        onError(sessionId: string, errorCode: number, errorMessage: string): void {
          service.recording = false;
          service.notifyStatus('语音识别暂不可用');
          service.release();
        }
      };
      this.engine.setListener(listener);
      this.engine.startListening({
        sessionId: this.sessionId,
        audioInfo: {
          audioType: 'pcm',
          sampleRate: 16000,
          soundChannel: 1,
          sampleBit: 16
        }
      });

      const options: audio.AudioCapturerOptions = {
        streamInfo: {
          samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
          channels: audio.AudioChannel.CHANNEL_1,
          sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
          encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
        },
        capturerInfo: {
          source: audio.SourceType.SOURCE_TYPE_VOICE_RECOGNITION,
          capturerFlags: 0
        }
      };
      this.capturer = await audio.createAudioCapturer(options);
      this.capturer.on('readData', (buffer: ArrayBuffer) => {
        service.writeAudioChunks(buffer);
      });
      await this.capturer.start();
      this.recording = true;
      this.notifyStatus('正在聆听');
      return true;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      console.error(`Voice recognition start failed: ${error.code}, ${error.message}`);
      this.notifyStatus('语音识别暂不可用');
      await this.release();
      return false;
    }
  }

  async stop(): Promise<void> {
    if (!this.recording) {
      await this.release();
      return;
    }
    this.recording = false;
    try {
      if (this.capturer !== undefined) {
        this.capturer.off('readData');
        await this.capturer.stop();
      }
      if (this.engine !== undefined && this.sessionId.length > 0) {
        this.engine.finish(this.sessionId);
      }
      this.notifyStatus('正在识别');
    } catch (err) {
      this.notifyStatus('语音识别已停止');
      await this.release();
    }
  }

  isRecording(): boolean {
    return this.recording;
  }

  async release(): Promise<void> {
    this.recording = false;
    if (this.capturer !== undefined) {
      try {
        this.capturer.off('readData');
        await this.capturer.release();
      } catch (err) {
        console.info('AudioCapturer already released');
      }
      this.capturer = undefined;
    }
    if (this.engine !== undefined) {
      try {
        this.engine.shutdown();
      } catch (err) {
        console.info('Speech engine already shutdown');
      }
      this.engine = undefined;
    }
    if (this.audioFile !== undefined) {
      try {
        fileIo.closeSync(this.audioFile);
      } catch (err) {
        console.info('Audio file already closed');
      }
      this.audioFile = undefined;
    }
    this.sessionId = '';
    this.pendingAudio = new Uint8Array(0);
  }

  private writeAudioChunks(buffer: ArrayBuffer): void {
    if (!this.recording || this.engine === undefined) {
      return;
    }
    const incoming: Uint8Array = new Uint8Array(buffer);
    if (this.audioFile !== undefined) {
      try {
        fileIo.writeSync(this.audioFile.fd, buffer);
      } catch (err) {
        this.notifyStatus('录音文件写入失败');
      }
    }
    const merged: Uint8Array = new Uint8Array(this.pendingAudio.length + incoming.length);
    merged.set(this.pendingAudio, 0);
    merged.set(incoming, this.pendingAudio.length);
    let offset: number = 0;
    while (offset + 1280 <= merged.length) {
      const chunk: Uint8Array = merged.slice(offset, offset + 1280);
      try {
        this.engine.writeAudio(this.sessionId, chunk);
      } catch (err) {
        this.recording = false;
        this.notifyStatus('语音数据处理失败');
        break;
      }
      offset += 1280;
    }
    this.pendingAudio = merged.slice(offset);
  }

  private async requestMicrophonePermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const permissions: Permissions[] = ['ohos.permission.MICROPHONE'];
      const result: PermissionRequestResult =
        await manager.requestPermissionsFromUser(context, permissions);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (err) {
      return false;
    }
  }

  private notifyStatus(status: string): void {
    if (this.statusCallback !== undefined) {
      this.statusCallback(status);
    }
  }
}
