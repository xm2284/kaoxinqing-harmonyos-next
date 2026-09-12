import { fileIo } from '@kit.CoreFileKit';
import { audio } from '@kit.AudioKit';

export class AffirmationAudioService {
  static async play(path: string): Promise<void> {
    const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    let renderer: audio.AudioRenderer | undefined = undefined;
    let writeDataCallback: audio.AudioRendererWriteDataCallback | undefined = undefined;
    try {
      const stat: fileIo.Stat = fileIo.statSync(path);
      if (stat.size <= 0) {
        return;
      }
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);
      const options: audio.AudioRendererOptions = {
        streamInfo: {
          samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
          channels: audio.AudioChannel.CHANNEL_1,
          sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
          encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
        },
        rendererInfo: {
          usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
          rendererFlags: 0
        }
      };
      const activeRenderer: audio.AudioRenderer = await audio.createAudioRenderer(options);
      renderer = activeRenderer;
      const source: Uint8Array = new Uint8Array(buffer);
      let offset: number = 0;
      writeDataCallback = (data: ArrayBuffer): audio.AudioDataCallbackResult => {
        const output: Uint8Array = new Uint8Array(data);
        const remaining: number = Math.max(0, source.length - offset);
        const length: number = Math.min(output.length, remaining);
        if (length > 0) {
          output.set(source.subarray(offset, offset + length));
          offset += length;
        }
        if (length < output.length) {
          output.fill(0, length);
        }
        return audio.AudioDataCallbackResult.VALID;
      };
      activeRenderer.on('writeData', writeDataCallback);
      const reached: Promise<void> = new Promise<void>((resolve: () => void) => {
        activeRenderer.on('markReach', Math.max(1, Math.floor(stat.size / 2)), () => { resolve(); });
      });
      await activeRenderer.start();
      await reached;
      await activeRenderer.stop();
    } finally {
      fileIo.closeSync(file);
      if (renderer !== undefined) {
        if (writeDataCallback !== undefined) {
          renderer.off('writeData', writeDataCallback);
        }
        await renderer.release();
      }
    }
  }
}
