export const clampPercent = (value: number | null): number | null => {
  if (typeof value !== 'number' || Number.isNaN(value)) {
    return null;
  }
  return Math.max(0, Math.min(100, Math.round(value)));
};

export const formatPercent = (value: number | null): string => {
  const clamped = clampPercent(value);
  if (clamped === null) {
    return '-';
  }
  return `${clamped}%`;
};

export const resolveUsageTone = (percent: number | null): 'safe' | 'warn' | 'critical' => {
  if (percent === null) {
    return 'safe';
  }
  if (percent >= 80) {
    return 'critical';
  }
  if (percent >= 50) {
    return 'warn';
  }
  return 'safe';
};

export const formatWindowLabel = (label: string): string => {
  if (label === '5h') return '5-Hour Limit';
  if (label === '7d') return '7-Day Limit';
  if (label === '7d-sonnet') return '7-Day Sonnet Limit';
  if (label === '7d-opus') return '7-Day Opus Limit';
  if (label === 'weekly') return 'Weekly Limit';
  if (label === 'monthly') return 'Monthly Limit';
  if (label === 'credits') return 'Credits';
  if (label === 'premium') return 'Premium Interactions';
  if (label === 'chat') return 'Chat Requests';
  if (label === 'completions') return 'Completions';
  if (label === 'premium_interactions') return 'Premium interactions';
  return label;
};
