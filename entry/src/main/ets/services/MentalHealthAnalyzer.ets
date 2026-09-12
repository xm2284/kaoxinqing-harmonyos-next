import { MentalHealthRecord } from '../common/DataModels';

export interface MentalHealthInsight {
  title: string;
  summary: string;
  pattern: string;
  suggestion: string;
  average: number;
  trackedDays: number;
  topFactor: string;
  attention: boolean;
}

/**
 * 完全在本机运行的轻量规则分析，只用于自我观察，不进行诊断。
 */
export class MentalHealthAnalyzer {
  static analyze(records: MentalHealthRecord[]): MentalHealthInsight {
    if (records.length === 0) {
      return {
        title: '从今天开始认识自己',
        summary: '完成第一次记录后，这里会呈现你的情绪趋势。',
        pattern: '暂无足够记录形成规律',
        suggestion: '可以从“此刻感觉如何”开始，不必写得很完整。',
        average: 0,
        trackedDays: 0,
        topFactor: '暂无',
        attention: false
      };
    }

    const recent: MentalHealthRecord[] = records.slice(0, Math.min(records.length, 7));
    let total: number = 0;
    let lowCount: number = 0;
    for (let index: number = 0; index < recent.length; index++) {
      total += recent[index].moodScore;
      if (recent[index].moodScore <= 3) {
        lowCount++;
      }
    }
    const average: number = total / recent.length;
    const factor: string = MentalHealthAnalyzer.mostFrequentFactor(recent);
    const trackedDays: number = MentalHealthAnalyzer.uniqueDayCount(recent);
    const delta: number = MentalHealthAnalyzer.trendDelta(recent);

    let title: string = '状态有些起伏';
    let summary: string = '最近的感受并不固定，继续记录会更容易看见变化。';
    let suggestion: string = '今天只选一件最能照顾自己的小事去做。';
    let attention: boolean = false;
    if (lowCount >= 3 || average <= 3.5) {
      title = '最近可能有些难熬';
      summary = '多次记录处在低位，这值得被认真对待，而不是独自扛着。';
      suggestion = '试着联系信任的人或专业支持；若有伤害自己的念头，请立即求助。';
      attention = true;
    } else if (delta <= -1.2) {
      title = '最近在慢慢下行';
      summary = '后几次记录比前几次更低，可能需要给自己减一点负荷。';
      suggestion = '先保证睡眠和进食，并把最困扰你的因素告诉可信任的人。';
    } else if (delta >= 1.2) {
      title = '状态正在回升';
      summary = '后几次记录比前几次更舒展，你的调整正在产生作用。';
      suggestion = '回想最近做对了什么，把有效的方法留在接下来的日子里。';
    } else if (average >= 7) {
      title = '最近较为舒展';
      summary = '近几次记录整体平稳偏积极，也要继续留意休息。';
      suggestion = '记下一件带来好感受的事，为以后保留可复用的线索。';
    }

    return {
      title: title,
      summary: summary,
      pattern: factor === '暂无' ? '尚未选择主要影响因素' : '“' + factor + '”出现得最频繁',
      suggestion: suggestion,
      average: Math.round(average * 10) / 10,
      trackedDays: trackedDays,
      topFactor: factor,
      attention: attention
    };
  }

  private static trendDelta(records: MentalHealthRecord[]): number {
    if (records.length < 4) {
      return 0;
    }
    const split: number = Math.floor(records.length / 2);
    let newer: number = 0;
    let older: number = 0;
    for (let index: number = 0; index < split; index++) {
      newer += records[index].moodScore;
    }
    for (let index: number = split; index < records.length; index++) {
      older += records[index].moodScore;
    }
    return newer / split - older / (records.length - split);
  }

  private static uniqueDayCount(records: MentalHealthRecord[]): number {
    const days: string[] = [];
    for (let index: number = 0; index < records.length; index++) {
      const day: string = records[index].recordedAt.substring(0, 10);
      if (days.indexOf(day) < 0) {
        days.push(day);
      }
    }
    return days.length;
  }

  private static mostFrequentFactor(records: MentalHealthRecord[]): string {
    const names: string[] = [];
    const counts: number[] = [];
    for (let recordIndex: number = 0; recordIndex < records.length; recordIndex++) {
      for (let factorIndex: number = 0; factorIndex < records[recordIndex].factors.length; factorIndex++) {
        const factor: string = records[recordIndex].factors[factorIndex];
        const existing: number = names.indexOf(factor);
        if (existing >= 0) {
          counts[existing]++;
        } else {
          names.push(factor);
          counts.push(1);
        }
      }
    }
    if (names.length === 0) {
      return '暂无';
    }
    let best: number = 0;
    for (let index: number = 1; index < counts.length; index++) {
      if (counts[index] > counts[best]) {
        best = index;
      }
    }
    return names[best];
  }
}
