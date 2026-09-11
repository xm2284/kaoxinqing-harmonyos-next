import { http } from '@kit.NetworkKit';
import { VideoShare } from '../common/DataModels';

interface BiliOwner { name: string; }
interface BiliStat { view: number; }
interface BiliData { bvid: string; title: string; pic: string; duration: number; owner: BiliOwner; stat: BiliStat; }
interface BiliResponse { code: number; data?: BiliData; }

export class BilibiliService {
  static async resolve(bvid: string): Promise<VideoShare> {
    if (!/^BV[0-9A-Za-z]{10}$/.test(bvid)) { throw new Error('无效的视频编号'); }
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request('https://api.bilibili.com/x/web-interface/view?bvid=' + bvid, {
        method: http.RequestMethod.GET,
        header: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://www.bilibili.com/' },
        connectTimeout: 8000, readTimeout: 10000
      });
      if (response.responseCode !== 200) { throw new Error('无法读取视频'); }
      const payload: BiliResponse = JSON.parse(response.result as string) as BiliResponse;
      if (payload.code !== 0 || payload.data === undefined || payload.data.bvid !== bvid) { throw new Error('视频不存在或暂不可访问'); }
      const data: BiliData = payload.data;
      return { bvid: data.bvid, title: data.title, coverUrl: data.pic.replace(/^http:/, 'https:'),
        duration: data.duration, views: data.stat.view, author: data.owner.name,
        shareReason: '', sharer: '', likes: 0, category: '治愈系', createdAt: new Date().toISOString() };
    } finally { request.destroy(); }
  }
}
