import { describe, expect, test } from 'bun:test';
import React from 'react';
import { renderToString } from 'react-dom/server';
import { SessionBusyIndicator } from '@/components/session/SessionBusyIndicator';

describe('SessionBusyIndicator', () => {
  test('renders with default size (14px)', () => {
    const html = renderToString(<SessionBusyIndicator />);
    expect(html).toContain('animate-spin');
    expect(html).toContain('viewBox="0 0 14 14"');
    expect(html).toContain('stroke-width="1.5"');
  });

  test('renders with custom size', () => {
    const html = renderToString(<SessionBusyIndicator size={18} />);
    expect(html).toContain('viewBox="0 0 18 18"');
    expect(html).toContain('width:18px;height:18px');
  });

  test('renders two circles (track + arc)', () => {
    const html = renderToString(<SessionBusyIndicator />);
    const circleMatches = html.match(/<circle/g);
    expect(circleMatches?.length).toBe(2);
  });

  test('uses theme tokens for stroke colors', () => {
    const html = renderToString(<SessionBusyIndicator />);
    expect(html).toContain('var(--interactive-border)');
    expect(html).toContain('var(--surface-muted-foreground)');
  });

  test('renders with stroke-linecap round on arc circle', () => {
    const html = renderToString(<SessionBusyIndicator />);
    expect(html).toContain('stroke-linecap="round"');
  });

  test('applies custom className', () => {
    const html = renderToString(<SessionBusyIndicator className="my-custom" />);
    expect(html).toContain('my-custom');
  });

  test('marks svg and wrapper as aria-hidden', () => {
    const html = renderToString(<SessionBusyIndicator />);
    const ariaHiddenCount = (html.match(/aria-hidden="true"/g) || []).length;
    expect(ariaHiddenCount).toBe(2);
  });

  test('renders correct arc geometry matching PC SessionNodeItem', () => {
    // PC ring: size=14, strokeWidth=1.5, radius=(14-1.5)/2=6.25
    // circumference = 2π × 6.25 ≈ 39.2699, arc = 0.28 × 39.2699 ≈ 10.9956
    const html = renderToString(<SessionBusyIndicator />);
    // Should contain a stroke-dasharray with the calculated arc + rest
    expect(html).toContain('stroke-dasharray="');
    // Verify the circumference calculation is consistent
    const match = html.match(/stroke-dasharray="([^"]+)"/);
    expect(match).not.toBeNull();
    const dasharray = match![1];
    const [arc, rest] = dasharray.split(' ').map(Number);
    // arc ≈ 11 (28% of ~39.27)
    expect(arc).toBeGreaterThan(10.5);
    expect(arc).toBeLessThan(11.5);
    // arc + rest ≈ circumference (~39.27)
    expect(arc + rest).toBeGreaterThan(39);
    expect(arc + rest).toBeLessThan(40);
  });
});
