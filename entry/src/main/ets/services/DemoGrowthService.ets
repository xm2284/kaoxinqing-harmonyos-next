export interface GrowthPoint { label: string; value: number; }
export interface DemoGrowthRecord { key: string; kind: number; title: string; text: string; date: string; }

// Presentation fixtures stay outside the personal database and never enter model context.
export class DemoGrowthService {
  static readonly BREATHS: number = 10;
  static readonly RESTS: number = 3;
  static readonly CHALLENGES: number = 4;
  static readonly CARDS: number = 12;
  static readonly DAYS: number = 7;
  static readonly MINUTES: number = 90;
  static points(): GrowthPoint[] {
    const levels: number[] = [7.2, 6.4, 6.8, 5.6, 5.1, 5.8, 4.6];
    return levels.map((value: number, index: number) => {
      const date: Date = new Date(); date.setDate(date.getDate() - 6 + index);
      return { label: (date.getMonth() + 1).toString() + '/' + date.getDate().toString(), value: value } as GrowthPoint;
    });
  }
  static records(): DemoGrowthRecord[] {
    const items: DemoGrowthRecord[] = [];
    for (let index: number = 0; index < 7; index++) {
      const date: Date = new Date(); date.setDate(date.getDate() - 6 + index); date.setHours(19, 30, 0, 0);
      items.push({ key: 'demo_assess_' + index, kind: 4, title: '示例 · 情绪自评',
        text: '压力参考值 ' + DemoGrowthService.points()[index].value.toFixed(1) + ' / 10', date: date.toISOString() });
    }
    const counts: number[] = [10, 3, 4, 12];
    const titles: string[] = ['云息呼吸', '松风休息', '认知重构', '今日翻卡'];
    const notes: string[] = ['完成 3 分钟舒缓呼吸', '完成 20 分钟安静休息',
      '原来的想法：一次没考好就说明我不行。\n新的看法：这次的错题能帮我找到下一步。',
      '今天先做好眼前这一件小事，就已经很好。'];
    counts.forEach((count: number, group: number) => {
      for (let index: number = 0; index < count; index++) {
        const date: Date = new Date(); date.setDate(date.getDate() - index % 7); date.setHours(18, 10 + index, 0, 0);
        items.push({ key: 'demo_' + group + '_' + index, kind: group === 3 ? 1 : (group === 2 ? 3 : 2),
          title: '示例 · ' + titles[group], text: notes[group], date: date.toISOString() });
      }
    });
    return items.sort((a: DemoGrowthRecord, b: DemoGrowthRecord) => b.date.localeCompare(a.date));
  }
}
