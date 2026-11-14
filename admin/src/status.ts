import type { LiveStage, ListingStatus, OrderStage, SellerStatus } from './store';
import type { Tone } from './ui';

export const orderTone: Record<OrderStage, Tone> = {
  newOrder: 'amber',
  accepted: 'blue',
  packed: 'violet',
  shipped: 'cyan',
  delivered: 'green',
  cancelled: 'red',
  returned: 'slate',
};
export const orderLabel: Record<OrderStage, string> = {
  newOrder: 'New',
  accepted: 'Accepted',
  packed: 'Packed',
  shipped: 'Shipped',
  delivered: 'Delivered',
  cancelled: 'Cancelled',
  returned: 'Returned',
};
export const orderFlow: OrderStage[] = ['newOrder', 'accepted', 'packed', 'shipped', 'delivered'];
/** Server action that moves an order to the next stage. */
export const nextAction: Partial<Record<OrderStage, [string, string]>> = {
  newOrder: ['accept', 'Accept'],
  accepted: ['pack', 'Mark packed'],
  packed: ['ship', 'Ship'],
  shipped: ['deliver', 'Mark delivered'],
};

export const listingTone: Record<ListingStatus, Tone> = {
  active: 'green',
  inReview: 'amber',
  paused: 'slate',
  draft: 'slate',
  rejected: 'red',
  soldOut: 'red',
};
export const listingLabel: Record<ListingStatus, string> = {
  active: 'Live',
  inReview: 'QC pending',
  paused: 'Paused',
  draft: 'Draft',
  rejected: 'Rejected',
  soldOut: 'Sold out',
};

export const sellerTone: Record<SellerStatus, Tone> = { pending: 'amber', approved: 'green', suspended: 'red' };
export const sellerLabel: Record<SellerStatus, string> = { pending: 'KYC pending', approved: 'Approved', suspended: 'Suspended' };

export const liveTone: Record<LiveStage, Tone> = { pending: 'amber', confirmed: 'blue', done: 'green', declined: 'slate' };
export const liveLabel: Record<LiveStage, string> = { pending: 'Pending', confirmed: 'Confirmed', done: 'Completed', declined: 'Declined' };

export const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
