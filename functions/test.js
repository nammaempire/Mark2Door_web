'use strict';
const assert = require('node:assert/strict');
const {
  newAssignment,
  cancelledForRider,
  displayId,
  rupees,
} = require('./notify');
const { customerNotice } = require('./customer');
const { quantities, pendingWork, hasWork, nextStock } = require('./stock');

const order = (over) => ({
  status: 'placed',
  riderPhone: '9900011111',
  paymentMethod: 'cod',
  totalPaise: 15000,
  walletAppliedPaise: 2500,
  items: [{}, {}],
  address: { pincode: '560034' },
  ...over,
});

// First assignment.
let n = newAssignment(order({ riderPhone: null }), order(), 'abc2d1746');
assert.equal(n.phone, '9900011111');
assert.equal(n.title, 'New order #2D1746');
assert.equal(n.body, '2 items · collect ₹125 cash · 560034. Open the app to accept.');

// Brand-new order created already assigned.
assert.ok(newAssignment(null, order(), 'x'));

// Reassigned to someone else notifies the new rider.
n = newAssignment(order(), order({ riderPhone: '9900022222' }), 'x');
assert.equal(n.phone, '9900022222');

// Same rider, some other field changed: no repeat.
assert.equal(newAssignment(order(), order({ riderRating: 5 }), 'x'), null);
// Rider accepted, rejected (phone cleared), or order deleted: nothing.
assert.equal(newAssignment(order({ riderPhone: null }), order({ status: 'accepted' }), 'x'), null);
assert.equal(newAssignment(order(), order({ riderPhone: null }), 'x'), null);
assert.equal(newAssignment(order(), null, 'x'), null);

// Paid online, one item, no pincode.
n = newAssignment(null, order({ paymentMethod: 'online', items: [{}], address: {} }), 'x');
assert.equal(n.body, '1 item · paid online. Open the app to accept.');

assert.equal(displayId('m2dXYZ12ab34cd'), '#AB34CD');
assert.equal(rupees(12550), '₹125.50');

// --- Rider is told when an order they hold is cancelled -------------------
n = cancelledForRider(order({ status: 'accepted' }), order({ status: 'cancelled', cancelledBy: 'customer' }), 'abc2d1746');
assert.equal(n.phone, '9900011111');
assert.equal(n.title, 'Order #2D1746 cancelled');
assert.equal(n.body, 'The customer cancelled this order. Do not pick it up or deliver it.');
n = cancelledForRider(order(), order({ status: 'cancelled' }), 'x');
assert.equal(n.body, 'This order was cancelled. Do not pick it up or deliver it.');
// No rider on it, already cancelled, or not a cancellation: nothing.
assert.equal(cancelledForRider(order({ riderPhone: null }), order({ riderPhone: null, status: 'cancelled' }), 'x'), null);
assert.equal(cancelledForRider(order({ status: 'cancelled' }), order({ status: 'cancelled', x: 1 }), 'x'), null);
assert.equal(cancelledForRider(order(), order({ status: 'accepted' }), 'x'), null);
assert.equal(cancelledForRider(null, order({ status: 'cancelled' }), 'x'), null);
console.log('notify tests passed');

// --- Customer notifications ----------------------------------------------
const mine = (over) => ({
  userId: 'u1',
  status: 'placed',
  paymentMethod: 'cod',
  paymentStatus: 'pending',
  totalPaise: 7200,
  walletAppliedPaise: 0,
  ...over,
});
const id = 'abc2d1746';

// Cash order: placed as soon as it is created.
let c = customerNotice(null, mine(), id);
assert.equal(c.uid, 'u1');
assert.equal(c.title, 'Order placed #2D1746');
assert.equal(c.body, 'We have your order and will deliver it soon. Keep ₹72 ready in cash.');

// Online order: nothing on creation, "placed" once the payment is in.
const online = (over) => mine({ paymentMethod: 'online', ...over });
assert.equal(customerNotice(null, online(), id), null);
c = customerNotice(online(), online({ paymentStatus: 'paid' }), id);
assert.equal(c.title, 'Order placed #2D1746');
assert.equal(c.body, 'Payment received. We will deliver your order soon.');

// Payment pending, then failed (which also cancels the order: one message).
c = customerNotice(online(), online({ paymentPendingAt: 111 }), id);
assert.equal(c.title, 'Payment pending for order #2D1746');
assert.equal(customerNotice(online({ paymentPendingAt: 111 }), online({ paymentPendingAt: 111, x: 1 }), id), null);
c = customerNotice(online(), online({ paymentStatus: 'failed', status: 'cancelled' }), id);
assert.equal(c.title, 'Payment failed');

// Refund sent by the admin.
c = customerNotice(online({ paymentStatus: 'paid', status: 'cancelled' }), online({ paymentStatus: 'refunded', status: 'cancelled' }), id);
assert.equal(c.title, 'Refund sent for order #2D1746');

// Outstation (courier) orders: paid, packed, shipped, delivered.
const parcel = (over) => online({ deliveryType: 'courier', courierEta: '3 to 5 days', paymentStatus: 'paid', ...over });
c = customerNotice(parcel({ paymentStatus: 'pending' }), parcel(), id);
assert.equal(c.body, 'Payment received. Your order is being prepared and reaches you in 3 to 5 days.');
c = customerNotice(parcel(), parcel({ status: 'accepted' }), id);
assert.equal(c.title, 'Order #2D1746 packed');
c = customerNotice(parcel({ status: 'accepted' }), parcel({ status: 'pickedUp', courierName: 'DTDC', trackingNumber: 'D123' }), id);
assert.equal(c.title, 'Order #2D1746 shipped');
assert.equal(c.body, 'Your parcel is on its way with DTDC. Tracking number D123. It reaches you in 3 to 5 days from the order date.');
c = customerNotice(parcel({ status: 'pickedUp' }), parcel({ status: 'delivered' }), id);
assert.equal(c.body, 'Your parcel has reached you. Enjoy!');
c = customerNotice(parcel(), parcel({ status: 'cancelled' }), id);
assert.equal(c.title, 'Order #2D1746 cancelled');
// An instant order being accepted by the rider stays silent, as before.
assert.equal(customerNotice(mine(), mine({ status: 'accepted' }), id), null);

// Delivery partner assigned; a different field changing does not repeat it.
c = customerNotice(mine(), mine({ riderName: 'Suresh' }), id);
assert.equal(c.title, 'Delivery partner assigned');
assert.equal(c.body, 'Suresh will bring order #2D1746 to you.');
assert.equal(customerNotice(mine({ riderName: 'Suresh' }), mine({ riderName: 'Suresh', assignedAt: 5 }), id), null);
// Rider accepting is not announced again.
assert.equal(customerNotice(mine({ riderName: 'Suresh' }), mine({ riderName: 'Suresh', status: 'accepted' }), id), null);

// Out for delivery, then delivered.
c = customerNotice(mine({ riderName: 'Suresh', status: 'accepted' }), mine({ riderName: 'Suresh', status: 'pickedUp' }), id);
assert.equal(c.title, 'Order #2D1746 is out for delivery');
assert.equal(c.body, 'Suresh is on the way to you.');
c = customerNotice(mine({ status: 'pickedUp' }), mine({ status: 'delivered' }), id);
assert.equal(c.title, 'Order #2D1746 delivered');
// The stock and rating flags written later do not announce anything.
assert.equal(customerNotice(mine({ status: 'delivered' }), mine({ status: 'delivered', riderRating: 5 }), id), null);
assert.equal(customerNotice(mine(), mine({ stockTaken: true }), id), null);

// Cancelled by the customer, with wallet money and an online payment on it.
c = customerNotice(
  online({ paymentStatus: 'paid', walletAppliedPaise: 2500 }),
  online({ paymentStatus: 'paid', walletAppliedPaise: 2500, status: 'cancelled', cancelledBy: 'customer' }),
  id,
);
assert.equal(c.title, 'Order #2D1746 cancelled');
assert.equal(c.body, 'You cancelled this order. ₹25 goes back to your m2d wallet. ₹47 will be refunded to the account you paid from.');
// Cancelled by the store, cash order: no money lines.
c = customerNotice(mine(), mine({ status: 'cancelled' }), id);
assert.equal(c.body, 'The store cancelled this order.');
// The wallet refund flag written afterwards does not announce again.
assert.equal(customerNotice(mine({ status: 'cancelled' }), mine({ status: 'cancelled', walletRefunded: true }), id), null);

// No customer on the order, or order deleted: nothing.
assert.equal(customerNotice(null, mine({ userId: '' }), id), null);
assert.equal(customerNotice(mine(), null, id), null);
console.log('customer tests passed');

// --- Stock, wallet and coupon work ---------------------------------------
assert.deepEqual(
  quantities({ items: [
    { productId: 'apple', quantity: 3 },
    { productId: 'milk', quantity: 1 },
    { productId: 'apple', quantity: 2 },
    { productId: '', quantity: 9 },
    { quantity: 4 },
    { productId: 'x', quantity: 0 },
  ] }),
  { apple: 5, milk: 1 },
);
assert.deepEqual(quantities({}), {});

// New order: take stock once.
let w = pendingWork({ status: 'placed' });
assert.equal(w.takeStock, true);
assert.equal(hasWork(w), true);
assert.equal(hasWork(pendingWork({ status: 'placed', stockTaken: true })), false);
assert.equal(hasWork(pendingWork({ status: 'delivered', stockTaken: true })), false);

// Cancelled after stock was taken: put it back once.
w = pendingWork({ status: 'cancelled', stockTaken: true });
assert.equal(w.returnStock, true);
assert.equal(w.takeStock, false);
assert.equal(hasWork(pendingWork({ status: 'cancelled', stockTaken: true, stockReturned: true })), false);

// Cancelled before stock was ever taken: nothing to move, just mark it.
w = pendingWork({ status: 'cancelled' });
assert.equal(w.skipStock, true);
assert.equal(w.takeStock, false);
assert.equal(w.returnStock, false);

// Wallet money comes back once, and only on cancelled orders.
w = pendingWork({ status: 'cancelled', stockTaken: true, stockReturned: true, walletAppliedPaise: 2500, userId: 'u1' });
assert.equal(w.refundWallet, true);
assert.equal(pendingWork({ status: 'cancelled', walletAppliedPaise: 2500, userId: 'u1', walletRefunded: true }).refundWallet, false);
assert.equal(pendingWork({ status: 'placed', walletAppliedPaise: 2500, userId: 'u1' }).refundWallet, false);
assert.equal(pendingWork({ status: 'cancelled', walletAppliedPaise: 0, userId: 'u1' }).refundWallet, false);
assert.deepEqual(pendingWork(null), {});

// 8 apples, 3 ordered, then the order is cancelled.
assert.equal(nextStock(8, -3), 5);
assert.equal(nextStock(5, 3), 8);
// Never below zero, and uncounted products are left alone.
assert.equal(nextStock(2, -5), 0);
assert.equal(nextStock(undefined, -1), null);
assert.equal(nextStock(null, 1), null);
console.log('stock tests passed');

// --- Razorpay payments ---------------------------------------------------
const crypto = require('crypto');
const {
  payablePaise,
  cannotPayReason,
  validPaymentSignature,
  validWebhookSignature,
  webhookAction,
  needsRefund,
} = require('./payments');

const pay = (over) => ({
  userId: 'u1',
  status: 'placed',
  paymentMethod: 'online',
  paymentStatus: 'pending',
  totalPaise: 7200,
  walletAppliedPaise: 2500,
  ...over,
});

// The amount is the order less the wallet, and never negative.
assert.equal(payablePaise(pay()), 4700);
assert.equal(payablePaise(pay({ walletAppliedPaise: 0 })), 7200);
assert.equal(payablePaise(pay({ walletAppliedPaise: 9000 })), 0);
assert.equal(payablePaise(null), 0);

// Only the owner of an open, unpaid online order can pay for it.
assert.equal(cannotPayReason(pay(), 'u1'), null);
assert.equal(cannotPayReason(pay(), 'someone-else'), 'This order belongs to someone else.');
assert.equal(cannotPayReason(pay({ paymentMethod: 'cod' }), 'u1'), 'This order is not paid online.');
assert.equal(cannotPayReason(pay({ status: 'cancelled' }), 'u1'), 'This order is no longer open.');
assert.equal(cannotPayReason(pay({ paymentStatus: 'paid' }), 'u1'), 'This order is already paid.');
assert.equal(cannotPayReason(pay({ walletAppliedPaise: 7200 }), 'u1'), 'There is nothing to pay.');
assert.equal(cannotPayReason(undefined, 'u1'), 'This order does not exist.');

// A payment counts only with Razorpay's own signature.
const secret = 'test_secret_123';
const good = crypto.createHmac('sha256', secret).update('order_ABC|pay_XYZ').digest('hex');
assert.equal(validPaymentSignature('order_ABC', 'pay_XYZ', good, secret), true);
assert.equal(validPaymentSignature('order_ABC', 'pay_OTHER', good, secret), false);
assert.equal(validPaymentSignature('order_ABC', 'pay_XYZ', good, 'wrong_secret'), false);
assert.equal(validPaymentSignature('order_ABC', 'pay_XYZ', 'made-up', secret), false);
assert.equal(validPaymentSignature('order_ABC', 'pay_XYZ', undefined, secret), false);
assert.equal(validPaymentSignature(undefined, 'pay_XYZ', good, secret), false);

// Webhooks are trusted only with the webhook secret's signature.
const body = JSON.stringify({ event: 'payment.captured' });
const hook = crypto.createHmac('sha256', 'hook_secret').update(body).digest('hex');
assert.equal(validWebhookSignature(body, hook, 'hook_secret'), true);
assert.equal(validWebhookSignature(body + ' ', hook, 'hook_secret'), false);
assert.equal(validWebhookSignature(body, hook, 'other'), false);
assert.equal(validWebhookSignature('', hook, 'hook_secret'), false);

// What each webhook event leads to.
assert.deepEqual(
  webhookAction({ event: 'payment.captured', payload: { payment: { entity: { id: 'pay_1', order_id: 'order_1', amount: 4700 } } } }),
  { kind: 'paid', razorpayOrderId: 'order_1', paymentId: 'pay_1', amountPaise: 4700 },
);
assert.deepEqual(
  webhookAction({ event: 'refund.processed', payload: { refund: { entity: { payment_id: 'pay_1' } } } }),
  { kind: 'refunded', paymentId: 'pay_1' },
);
assert.equal(webhookAction({ event: 'payment.failed', payload: {} }), null);
assert.equal(webhookAction({ event: 'payment.captured', payload: {} }), null);
assert.equal(webhookAction(null), null);

// A cancelled order that was paid online is refunded once.
const paid = pay({ status: 'cancelled', paymentStatus: 'paid', paymentId: 'pay_1' });
assert.equal(needsRefund(paid), true);
assert.equal(needsRefund({ ...paid, refundRequestedAt: 5 }), false);
assert.equal(needsRefund({ ...paid, paymentStatus: 'refunded' }), false);
assert.equal(needsRefund({ ...paid, status: 'placed' }), false);
assert.equal(needsRefund({ ...paid, paymentMethod: 'cod' }), false);
assert.equal(needsRefund({ ...paid, paymentId: '' }), false);
// Fully paid from the wallet: nothing went through Razorpay.
assert.equal(needsRefund({ ...paid, walletAppliedPaise: 7200 }), false);
assert.equal(needsRefund(null), false);
console.log('payment tests passed');

// Announcements: "Notify customers" in the admin web.
const { announcementMessage, TOPIC } = require('./announce');
assert.equal(TOPIC, 'offers');
assert.deepEqual(
  announcementMessage({ title: '  Flat 20% off  ', body: 'Use code\nSAVE20 today.', status: 'sending' }),
  { title: 'Flat 20% off', body: 'Use code SAVE20 today.' },
);
assert.equal(announcementMessage({ title: 'x'.repeat(80), body: 'y' }).title.length, 50);
assert.equal(announcementMessage({ title: '', body: 'Hello' }), null);
assert.equal(announcementMessage({ title: 'Hi', body: '   ' }), null);
assert.equal(announcementMessage({ title: 'Hi', body: 'There', status: 'sent' }), null);
assert.equal(announcementMessage(null), null);
console.log('announcement tests passed');

// Several stores: an order moves its own store's stock.
const { stockTarget } = require('./stock');
const shared = { stockQty: 9, storeStock: { s1: { inStock: true, stockQty: 4 }, s2: { inStock: true, stockQty: null } } };
assert.deepEqual(stockTarget(shared, 's1'), { field: 'storeStock.s1.stockQty', current: 4 });
// A store that does not count the product: nothing to move.
assert.deepEqual(stockTarget(shared, 's2'), { field: 'storeStock.s2.stockQty', current: null });
// No entry for the store, or no store at all: the product's own count.
assert.deepEqual(stockTarget(shared, 's3'), { field: 'stockQty', current: 9 });
assert.deepEqual(stockTarget(shared, undefined), { field: 'stockQty', current: 9 });
assert.deepEqual(stockTarget({ stockQty: 2 }, 's1'), { field: 'stockQty', current: 2 });
console.log('store stock tests passed');

// A reported success is accepted only if Razorpay records it as paid.
const { paymentProblem } = require('./payments');
const rzpOrder = { razorpayOrderId: 'order_1', totalPaise: 18500 };
const goodPay = { order_id: 'order_1', status: 'captured', amount: 18500, method: 'upi' };
assert.equal(paymentProblem(goodPay, rzpOrder), null);
assert.equal(paymentProblem({ ...goodPay, status: 'authorized' }, rzpOrder), null);
assert.equal(paymentProblem({ ...goodPay, status: 'failed' }, rzpOrder), 'Razorpay shows this payment as failed.');
assert.equal(paymentProblem({ ...goodPay, status: 'created' }, rzpOrder), 'Razorpay shows this payment as created.');
assert.equal(paymentProblem({ ...goodPay, order_id: 'order_2' }, rzpOrder), 'This payment belongs to a different order.');
assert.equal(paymentProblem({ ...goodPay, amount: 100 }, rzpOrder), 'The amount paid does not match the order.');
assert.equal(paymentProblem(null, rzpOrder), 'Payment not found.');
// Wallet money already used comes off what Razorpay must have collected.
assert.equal(paymentProblem({ ...goodPay, amount: 16000 }, { ...rzpOrder, walletAppliedPaise: 2500 }), null);
console.log('payment check tests passed');

// The server works out what an order should cost and refuses less.
const { checkOrder, couponDiscount, feesFor } = require('./pricecheck');
const catalogue = {
  apple: { pricePaise: 12900 },
  milk: { pricePaise: 3200 },
};
const storeFees = { deliveryFeePaise: 3000, freeDeliveryThresholdPaise: 49900, handlingFeeEnabled: true, handlingFeePaise: 500, rainFeeEnabled: false, rainFeePaise: 2000 };
const slab = [{ minOrderPaise: 29900, offerPricePaise: 900, productIds: ['milk'], active: true }];
const ctx = { products: catalogue, settings: storeFees, coupon: null, offers: slab, now: 1000 };
const honest = {
  items: [{ productId: 'apple', quantity: 3, pricePaise: 12900 }],
  totalPaise: 38700 + 3000 + 500,
  deliveryType: 'instant',
};
assert.deepEqual(checkOrder(honest, ctx), { ok: true, expectedTotalPaise: 42200, reason: null });
// Paying more than needed (a price went down) is not refused.
assert.equal(checkOrder({ ...honest, totalPaise: 50000 }, ctx).ok, true);
// A tampered app: item price of 1 paise, total to match.
const cheat = { ...honest, items: [{ productId: 'apple', quantity: 3, pricePaise: 1 }], totalPaise: 3 };
assert.equal(checkOrder(cheat, ctx).ok, false);
assert.equal(checkOrder(cheat, ctx).expectedTotalPaise, 42200);
// Fees left off.
assert.equal(checkOrder({ ...honest, totalPaise: 38700 }, ctx).ok, false);
// Negative or fractional quantity, unknown product, no items.
assert.equal(checkOrder({ ...honest, items: [{ productId: 'apple', quantity: -2 }] }, ctx).ok, false);
assert.equal(checkOrder({ ...honest, items: [{ productId: 'apple', quantity: 1.5 }] }, ctx).ok, false);
assert.equal(checkOrder({ ...honest, items: [{ productId: 'ghost', quantity: 1 }] }, ctx).ok, false);
assert.equal(checkOrder({ ...honest, items: [] }, ctx).ok, false);
// The offer product at the offer price, once the items earn it.
const withOffer = {
  ...honest,
  items: [...honest.items, { productId: 'milk', quantity: 1, pricePaise: 900, offer: true }],
  totalPaise: 38700 + 900 + 3000 + 500,
};
assert.equal(checkOrder(withOffer, ctx).ok, true);
// Items below the offer amount: the product counts at its usual price.
const early = {
  ...honest,
  items: [{ productId: 'apple', quantity: 1 }, { productId: 'milk', quantity: 1, pricePaise: 900, offer: true }],
  totalPaise: 12900 + 900 + 3000 + 500,
};
assert.equal(checkOrder(early, ctx).ok, false);
assert.equal(checkOrder(early, ctx).expectedTotalPaise, 12900 + 3200 + 3000 + 500);
// An offer price the admin never set, two units, or the offer switched off.
assert.equal(checkOrder({ ...withOffer, items: [honest.items[0], { productId: 'milk', quantity: 1, pricePaise: 100, offer: true }], totalPaise: 38700 + 100 + 3500 }, ctx).ok, false);
assert.equal(checkOrder({ ...withOffer, items: [honest.items[0], { productId: 'milk', quantity: 2, pricePaise: 900, offer: true }] }, ctx).ok, false);
assert.equal(checkOrder(withOffer, { ...ctx, offers: [{ ...slab[0], active: false }] }).ok, false);
// Coupons: 10% up to Rs 20, with a minimum and an expiry.
const tenOff = { type: 'percent', value: 10, maxDiscountPaise: 2000, minOrderPaise: 20000, active: true, expiresAt: 5000 };
assert.equal(couponDiscount(tenOff, 38700, 1000), 2000);
assert.equal(couponDiscount(tenOff, 15000, 1000), 0);
assert.equal(couponDiscount(tenOff, 38700, 6000), 0);
assert.equal(couponDiscount({ ...tenOff, active: false }, 38700, 1000), 0);
assert.equal(couponDiscount({ type: 'flat', value: 5000 }, 3000, 1000), 3000);
const couponed = { ...honest, couponCode: 'TEN', totalPaise: 42200 - 2000 };
assert.equal(checkOrder(couponed, { ...ctx, coupon: tenOff }).ok, true);
// A made-up discount, or a coupon that does not exist.
assert.equal(checkOrder({ ...couponed, totalPaise: 100 }, { ...ctx, coupon: tenOff }).ok, false);
assert.equal(checkOrder(couponed, { ...ctx, coupon: null }).ok, false);
// Outstation: the courier charge instead of the instant charges.
assert.equal(feesFor(38700, true, { courierFeePaise: 6000, courierFreeAbovePaise: 99900 }), 6000);
assert.equal(feesFor(120000, true, {}), 0);
assert.equal(feesFor(60000, false, storeFees), 500);
assert.equal(checkOrder({ ...honest, deliveryType: 'courier', totalPaise: 38700 + 6000 }, ctx).ok, true);
// Wallet money can never be more than the order.
assert.equal(checkOrder({ ...honest, walletAppliedPaise: 99999 }, ctx).ok, false);
console.log('price check tests passed');

// Daily sales totals kept by the server.
const { dayOf, contribution, changes, totalsFor } = require('./stats');
// 26 Nov 2026 00:10 in India is still 25 Nov in UTC.
const at = Date.UTC(2026, 10, 25, 18, 40);
assert.equal(dayOf(at), '2026-11-26');
const codOrder = {
  createdAt: at, storeId: 's1', status: 'placed', paymentMethod: 'cod',
  paymentStatus: 'pending', totalPaise: 30000, deliveryFeePaise: 3000,
  items: [{ name: 'Apple', quantity: 2, pricePaise: 12900 }, { name: 'Milk (Offer)', quantity: 1, pricePaise: 900 }],
};
const c1 = contribution(codOrder);
assert.equal(c1.docId, '2026-11-26__s1');
assert.deepEqual(c1.totals, { orders: 1, revenueOrders: 1, revenuePaise: 30000, cancelledOrders: 0, unpaidOrders: 0, codPaise: 30000, onlinePaise: 0, deliveryFeesPaise: 3000 });
assert.deepEqual(c1.items, { Apple: { q: 2, p: 25800 }, 'Milk (Offer)': { q: 1, p: 900 } });
// An online order counts only once paid.
const unpaid = { ...codOrder, storeId: undefined, paymentMethod: 'online' };
assert.equal(contribution(unpaid).docId, '2026-11-26__none');
assert.equal(contribution(unpaid).totals.unpaidOrders, 1);
assert.equal(contribution(unpaid).totals.revenuePaise, 0);
const paidOnline = { ...unpaid, paymentStatus: 'paid' };
assert.equal(contribution(paidOnline).totals.onlinePaise, 30000);
assert.equal(contribution(null), null);
assert.equal(contribution({ status: 'placed' }), null);
// A new order adds itself.
assert.deepEqual(changes(null, codOrder)['2026-11-26__s1'].totals, { orders: 1, revenueOrders: 1, revenuePaise: 30000, codPaise: 30000, deliveryFeesPaise: 3000 });
// A change that does not touch the totals (a rider accepts) changes nothing.
assert.deepEqual(changes(codOrder, { ...codOrder, status: 'accepted', riderName: 'Abdul' }), {});
// Payment arriving moves the order from unpaid to revenue.
assert.deepEqual(changes(unpaid, paidOnline)['2026-11-26__none'].totals, { revenueOrders: 1, revenuePaise: 30000, unpaidOrders: -1, onlinePaise: 30000, deliveryFeesPaise: 3000 });
// Cancelling takes the revenue and the items back out.
const cancelled = changes(codOrder, { ...codOrder, status: 'cancelled' })['2026-11-26__s1'];
assert.deepEqual(cancelled.totals, { revenueOrders: -1, revenuePaise: -30000, cancelledOrders: 1, codPaise: -30000, deliveryFeesPaise: -3000 });
assert.deepEqual(cancelled.items, { Apple: { q: -2, p: -25800 }, 'Milk (Offer)': { q: -1, p: -900 } });
// Adding every order's changes one by one gives the same as a rebuild.
const history = [[null, codOrder], [null, unpaid], [unpaid, paidOnline], [codOrder, { ...codOrder, status: 'cancelled' }]];
const running = {};
for (const [b, a] of history) {
  for (const [id, ch] of Object.entries(changes(b, a))) {
    const r = running[id] || (running[id] = {});
    for (const [k, v] of Object.entries(ch.totals)) r[k] = (r[k] || 0) + v;
  }
}
const rebuilt = totalsFor([{ ...codOrder, status: 'cancelled' }, paidOnline]);
for (const id of Object.keys(rebuilt)) {
  for (const [k, v] of Object.entries(rebuilt[id].totals)) assert.equal(running[id][k] || 0, v, id + ' ' + k);
}
console.log('daily totals tests passed');

// Customer records kept by the server.
const { customerChanges, customerTotalsFor } = require('./stats');
const asha = { ...codOrder, address: { phone: '9876543210', name: 'Asha', pincode: '629001' } };
const placedByAsha = customerChanges(null, asha);
assert.deepEqual(Object.keys(placedByAsha).sort(), ['2026-11__s1__9876543210', 'all__s1__9876543210']);
assert.deepEqual(placedByAsha['all__s1__9876543210'], {
  period: 'all', storeId: 's1', phone: '9876543210', orders: 1, spentPaise: 30000,
  latest: { name: 'Asha', pincode: '629001', lastOrderAt: at },
});
// Cancelling keeps the order in her count and takes the money back out.
const ashaCancels = customerChanges(asha, { ...asha, status: 'cancelled' });
assert.deepEqual(ashaCancels['2026-11__s1__9876543210'], { period: '2026-11', storeId: 's1', phone: '9876543210', orders: 0, spentPaise: -30000, latest: null });
// A rider accepting changes nothing; an order with no phone has no record.
assert.deepEqual(customerChanges(asha, { ...asha, status: 'accepted' }), {});
assert.deepEqual(customerChanges(null, codOrder), {});
// A rebuild keeps the newest order's name and pincode.
const later = { ...asha, createdAt: at + 86400000, address: { phone: '9876543210', name: 'Asha R', pincode: '629002' } };
const rebuiltCustomers = customerTotalsFor([later, asha]);
assert.equal(rebuiltCustomers['all__s1__9876543210'].orders, 2);
assert.equal(rebuiltCustomers['all__s1__9876543210'].spentPaise, 60000);
assert.equal(rebuiltCustomers['all__s1__9876543210'].latest.name, 'Asha R');
console.log('customer totals tests passed');

// Invite rewards paid by the server.
const { milestonesReached, rewardFor, needsRewardCheck } = require('./rewards');
assert.deepEqual([0, 1, 2, 3, 5, 6, 10, 15, 40].map(milestonesReached), [0, 1, 1, 2, 2, 3, 4, 5, 5]);
// The first friend earns Rs 25.
assert.deepEqual(rewardFor({}), { invites: 1, due: 1, balancePaise: 2500, rewardedMilestones: 1, note: 'Invite reward: 1 friend has ordered' });
// The second friend counts but earns nothing; the third earns the next.
const afterOne = { successfulInvites: 1, rewardedMilestones: 1, balancePaise: 2500 };
assert.equal(rewardFor(afterOne).due, 0);
assert.equal(rewardFor(afterOne).balancePaise, 2500);
const afterTwo = { successfulInvites: 2, rewardedMilestones: 1, balancePaise: 1000 };
assert.deepEqual(rewardFor(afterTwo), { invites: 3, due: 1, balancePaise: 3500, rewardedMilestones: 2, note: 'Invite reward: 3 friends have ordered' });
// Nothing more after the fifth reward (15 friends).
assert.equal(rewardFor({ successfulInvites: 20, rewardedMilestones: 5, balancePaise: 0 }).due, 0);
// A reward that was missed earlier is made up.
assert.equal(rewardFor({ successfulInvites: 5, rewardedMilestones: 1, balancePaise: 0 }).due, 2);
// Only a delivered order that has not been checked is looked at.
assert.equal(needsRewardCheck({ status: 'delivered', userId: 'u1' }), true);
assert.equal(needsRewardCheck({ status: 'delivered', userId: 'u1', referralChecked: true }), false);
assert.equal(needsRewardCheck({ status: 'placed', userId: 'u1' }), false);
assert.equal(needsRewardCheck({ status: 'delivered', userId: '' }), false);
assert.equal(needsRewardCheck(null), false);
console.log('invite reward tests passed');
