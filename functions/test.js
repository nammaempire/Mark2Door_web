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
