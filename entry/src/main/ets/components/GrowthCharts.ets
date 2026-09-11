import { GrowthPoint } from '../services/DemoGrowthService';

@Component
export struct GrowthDonut {
  @Prop @Watch('redraw') values: number[] = [];
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private ready: boolean = false;
  private readonly colors: string[] = ['#4C90DF', '#4DAA8E', '#A280CC'];
  private total(): number { return this.values.reduce((sum: number, item: number) => sum + Math.max(0, item), 0); }
  private redraw(): void {
    if (!this.ready) { return; }
    const ctx: CanvasRenderingContext2D = this.context;
    ctx.clearRect(0, 0, 136, 136); ctx.lineWidth = 15; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.arc(68, 68, 52, 0, Math.PI * 2); ctx.strokeStyle = '#EAF0F5'; ctx.stroke();
    let start: number = -Math.PI / 2;
    const total: number = this.total();
    this.values.forEach((value: number, index: number) => {
      if (value <= 0 || total === 0) { return; }
      const angle: number = value / total * Math.PI * 2;
      const gap: number = Math.min(0.09, angle * 0.22);
      ctx.beginPath(); ctx.arc(68, 68, 52, start + gap, start + angle - gap);
      ctx.strokeStyle = this.colors[index % 3]; ctx.stroke(); start += angle;
    });
  }
  build() {
    Stack() {
      Canvas(this.context).width(136).height(136).onReady(() => { this.ready = true; this.redraw(); })
      Column({ space: 3 }) {
        Text(this.total().toString()).fontSize(29).fontWeight(FontWeight.Bold).fontColor('#274362')
        Text('次调节').fontSize(11).fontColor('#667B90')
      }
    }.width(136).height(136).accessibilityText('已完成调节共 ' + this.total().toString() + ' 次，详细分类见右侧图例')
  }
}

@Component
export struct GrowthTrend {
  @Prop @Watch('redraw') points: GrowthPoint[] = [];
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private chartWidth: number = 300;
  private ready: boolean = false;
  private redraw(): void {
    if (!this.ready) { return; }
    const ctx: CanvasRenderingContext2D = this.context;
    const width: number = this.chartWidth;
    ctx.clearRect(0, 0, width, 118); ctx.lineWidth = 1;
    [0, 5, 10].forEach((tick: number) => {
      const y: number = 96 - tick * 8;
      ctx.beginPath(); ctx.moveTo(24, y); ctx.lineTo(width - 12, y); ctx.strokeStyle = '#E3EDF3'; ctx.stroke();
      ctx.font = '10px sans-serif'; ctx.fillStyle = '#8191A2'; ctx.fillText(tick.toString(), 3, y + 3);
    });
    if (this.points.length === 0) { return; }
    const step: number = (width - 44) / Math.max(1, this.points.length - 1);
    ctx.beginPath();
    this.points.forEach((item: GrowthPoint, index: number) => {
      const x: number = 28 + index * step; const y: number = 96 - Math.max(0, Math.min(10, item.value)) * 8;
      if (index === 0) { ctx.moveTo(x, y); } else { ctx.lineTo(x, y); }
    });
    ctx.lineWidth = 2.5; ctx.strokeStyle = '#4D90C9'; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.stroke();
    this.points.forEach((item: GrowthPoint, index: number) => {
      const x: number = 28 + index * step; const y: number = 96 - Math.max(0, Math.min(10, item.value)) * 8;
      ctx.beginPath(); ctx.arc(x, y, 4, 0, Math.PI * 2); ctx.fillStyle = '#FFFFFF'; ctx.fill();
      ctx.lineWidth = 2; ctx.strokeStyle = '#4D90C9'; ctx.stroke();
      ctx.fillStyle = '#315D7E'; ctx.textAlign = 'center'; ctx.font = '10px sans-serif'; ctx.fillText(item.value.toFixed(1), x, y - 10);
    });
    ctx.textAlign = 'start';
  }
  build() {
    Column({ space: 0 }) {
      Canvas(this.context).width('100%').height(118)
        .onReady(() => { this.ready = true; this.redraw(); })
        .onAreaChange((_old: Area, area: Area) => { this.chartWidth = Number(area.width); this.redraw(); })
      Row() {
        ForEach(this.points, (item: GrowthPoint) => { Text(item.label).fontSize(9).fontColor('#667B90').layoutWeight(1).textAlign(TextAlign.Center) })
      }.width('100%').padding({ left: 18 })
    }.width('100%').accessibilityText(this.points.map((item: GrowthPoint) => item.label + ' 压力参考值 ' + item.value.toFixed(1)).join('，'))
  }
}
