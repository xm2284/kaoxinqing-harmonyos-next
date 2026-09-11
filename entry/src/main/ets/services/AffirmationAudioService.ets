import { fileIo } from '@kit.CoreFileKit';
import { audio } from '@kit.AudioKit';

export class AffirmationAudioService {
  static async play(path: string): Promise<void> {
    const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    let renderer: audio.AudioRenderer | undefined = undefined;
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
      renderer = await audio.createAudioRenderer(options);
      await renderer.start();
      await renderer.write(buffer);
      await renderer.drain();
      await renderer.stop();
    } finally {
      fileIo.closeSync(file);
      if (renderer !== undefined) {
        await renderer.release();
      }
    }
  }
}
