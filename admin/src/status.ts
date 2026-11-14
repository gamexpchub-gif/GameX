import type { LiveStatus, OrderStatus } from './store';
import type { Tone } from './ui';

export const orderTone: Record<OrderStatus, Tone> = {
  pending: 'amber',
  confirmed: 'blue',
  packed: 'violet',
  shipped: 'cyan',
  delivered: 'green',
  cancelled: 'red',
  returned: 'slate',
};
export const orderFlow: OrderStatus[] = ['pending', 'confirmed', 'packed', 'shipped', 'delivered'];
export const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

export const liveTone: Record<LiveStatus, Tone> = {
  requested: 'amber',
  scheduled: 'blue',
  live: 'red',
  completed: 'green',
  cancelled: 'slate',
};
