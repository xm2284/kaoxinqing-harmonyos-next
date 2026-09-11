import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';

export class AmbientAudioService {
  private player: media.AVPlayer | undefined = undefined;
  private context: common.Context | undefined = undefined;
  private fileName: string = '';
  private generation: number = 0;
  private volume: number = 0.45;
  private cancelPending: (() => void) | undefined = undefined;
  onPlaybackChanged: (playing: boolean) => void = () => {};

  setVolume(value: number): void {
    this.volume = Math.max(0, Math.min(1, value));
    if (this.player !== undefined && (this.player.state === 'playing' || this.player.state === 'prepared')) {
      this.player.setVolume(this.volume);
    }
  }

  async play(context: common.Context, fileName: string): Promise<void> {
    await this.stop();
    const generation: number = this.generation;
    const player: media.AVPlayer = await media.createAVPlayer();
    if (generation !== this.generation) { await player.release(); return; }
    this.player = player;
    this.context = context;
    this.fileName = fileName;
    try {
      const descriptor = await context.resourceManager.getRawFd(fileName);
      if (generation !== this.generation) { await this.stop(); return; }
      await new Promise<void>((resolve, reject) => {
        let settled: boolean = false;
        let timer: number = -1;
        const fail = (): void => {
          if (!settled) { settled = true; clearTimeout(timer); this.cancelPending = undefined; reject(new Error('环境声未能播放')); }
          this.onPlaybackChanged(false);
        };
        this.cancelPending = fail;
        player.on('error', () => { fail(); });
        player.on('stateChange', (state: string) => {
          if (generation !== this.generation) { fail(); return; }
          if (state === 'initialized') {
            player.prepare().catch(() => { fail(); });
          } else if (state === 'prepared') {
            player.loop = true; player.setVolume(this.volume);
            player.play().catch(() => { fail(); });
          } else if (state === 'playing') {
            if (!settled) { settled = true; clearTimeout(timer); this.cancelPending = undefined; resolve(); }
            this.onPlaybackChanged(true);
          } else if (state === 'paused' || state === 'stopped' || state === 'released') {
            this.onPlaybackChanged(false);
          }
        });
        timer = setTimeout(fail, 8000);
        player.fdSrc = { fd: descriptor.fd, offset: descriptor.offset, length: descriptor.length };
      });
    } catch (reason) { await this.stop(); throw new Error('环境声加载失败'); }
  }

  async stop(): Promise<void> {
    this.generation++;
    if (this.cancelPending !== undefined) { this.cancelPending(); this.cancelPending = undefined; }
    const player: media.AVPlayer | undefined = this.player;
    const context: common.Context | undefined = this.context;
    const fileName: string = this.fileName;
    this.player = undefined; this.fileName = ''; this.context = undefined;
    try { if (player !== undefined) { await player.release(); } }
    finally {
      if (context !== undefined && fileName.length > 0) {
        await context.resourceManager.closeRawFd(fileName).catch(() => {});
      }
      this.onPlaybackChanged(false);
    }
  }
}
