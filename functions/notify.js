'use strict';

// Decides what, if anything, to tell a delivery partner when an order
// document changes. Kept free of Firebase so it can be tested on its own.

/** Order number as the apps show it, e.g. "#2D1746". */
function displayId(orderId) {
  const id = String(orderId || '');
  return '#' + id.slice(-6).toUpperCase();
}

function rupees(paise) {
  const n = Number(paise) || 0;
  return '₹' + (n % 100 === 0 ? String(n / 100) : (n / 100).toFixed(2));
}

/**
 * Returns `{phone, title, body}` when the change means a rider was just
 * given this order, otherwise null.
 *
 * A rider is "just given" an order when the order still needs accepting
 * (status "placed") and its `riderPhone` is set to a number that was not on
 * it before: a first assignment, or a reassignment to someone else.
 */
function newAssignment(before, after, orderId) {
  if (!after) return null; // order deleted
  const phone = after.riderPhone;
  if (typeof phone !== 'string' || phone === '') return null;
  if (after.status !== 'placed') return null;
  if (before && before.riderPhone === phone) return null; // nothing new

  const items = Array.isArray(after.items) ? after.items.length : 0;
  const cash = after.paymentMethod === 'cod';
  const payable =
    (Number(after.totalPaise) || 0) - (Number(after.walletAppliedPaise) || 0);
  const pincode = after.address && after.address.pincode;

  const parts = [
    items + (items === 1 ? ' item' : ' items'),
    cash ? 'collect ' + rupees(payable) + ' cash' : 'paid online',
  ];
  if (pincode) parts.push(String(pincode));

  return {
    phone,
    title: 'New order ' + displayId(orderId),
    body: parts.join(' · ') + '. Open the app to accept.',
  };
}

/**
 * Returns `{phone, title, body}` when the change means an order this rider
 * was handling has just been cancelled, otherwise null. A rider who has
 * already delivered it, or was never given it, is not told.
 */
function cancelledForRider(before, after, orderId) {
  if (!before || !after) return null;
  if (after.status !== 'cancelled' || before.status === 'cancelled') return null;
  const phone = after.riderPhone;
  if (typeof phone !== 'string' || phone === '') return null;
  return {
    phone,
    title: 'Order ' + displayId(orderId) + ' cancelled',
    body:
      (after.cancelledBy === 'customer'
        ? 'The customer cancelled this order. '
        : 'This order was cancelled. ') + 'Do not pick it up or deliver it.',
  };
}

module.exports = { newAssignment, cancelledForRider, displayId, rupees };
