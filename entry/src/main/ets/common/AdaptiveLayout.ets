// Sizes are based on the available content area, after system bars and navigation.
export class AdaptiveLayout {
  static pagePadding(width: number): number {
    return width < 360 ? 14 : 20;
  }

  static density(height: number): number {
    return Math.max(0.76, Math.min(1, height / 760));
  }

  static daysUntil(date: string): number {
    const parts: string[] = date.split('-');
    if (parts.length !== 3) {
      return 0;
    }
    const now: Date = new Date();
    const today: number = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
    const target: number = Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    return Number.isFinite(target) ? Math.max(0, Math.round((target - today) / 86400000)) : 0;
  }
}
