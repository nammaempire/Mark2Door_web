'use strict';

// Decides what, if anything, to tell a customer when their order document
// changes. Kept free of Firebase so it can be tested on its own.

const { displayId, rupees } = require('./notify');

/**
 * Returns `{uid, title, body}` for the one thing worth telling the
 * customer about this change, otherwise null.
 *
 * Covered: order placed, payment pending, payment failed, refund sent,
 * delivery partner assigned, out for delivery, delivered and cancelled.
 * Outstation orders (deliveryType "courier") are told packed and shipped
 * with the tracking number instead of the delivery partner messages.
 * An order paid online is announced as "placed" only once the payment has
 * gone through, so a customer is never told about an order that then fails.
 */
function customerNotice(before, after, orderId) {
  if (!after) return null; // order deleted
  const uid = after.userId;
  if (typeof uid !== 'string' || uid === '') return null;

  const id = displayId(orderId);
  const say = (title, body) => ({ uid, title, body });
  const was = before || {};
  const became = (field, value) =>
    after[field] === value && was[field] !== value;

  const payable =
    (Number(after.totalPaise) || 0) - (Number(after.walletAppliedPaise) || 0);
  const wallet = Number(after.walletAppliedPaise) || 0;
  const online = after.paymentMethod === 'online';
  const courier = after.deliveryType === 'courier';
  const days = after.courierEta || 'a few days';

  // A new cash order is placed the moment it is created.
  if (!before) {
    if (!online && after.status === 'placed') {
      return say(
        'Order placed ' + id,
        'We have your order and will deliver it soon.' +
          (payable > 0 ? ' Keep ' + rupees(payable) + ' ready in cash.' : ''),
      );
    }
    return null;
  }

  // Money first: these matter most to the customer.
  if (became('paymentStatus', 'failed')) {
    return say(
      'Payment failed',
      'Order ' + id + ' was not placed. If money was deducted, it will be ' +
        'refunded automatically.',
    );
  }
  if (became('paymentStatus', 'refunded')) {
    return say(
      'Refund sent for order ' + id,
      'Your money has been returned to the account you paid from. Banks ' +
        'can take a few days to show it.',
    );
  }
  if (became('paymentStatus', 'paid') && online && after.status === 'placed') {
    return say(
      'Order placed ' + id,
      courier
        ? 'Payment received. Your order is being prepared and ' +
            'reaches you in ' + days + '.'
        : 'Payment received. We will deliver your order soon.',
    );
  }
  if (
    after.paymentStatus === 'pending' &&
    online &&
    after.paymentPendingAt &&
    after.paymentPendingAt !== was.paymentPendingAt
  ) {
    return say(
      'Payment pending for order ' + id,
      'We are waiting for your bank to confirm the payment. Your order is ' +
        'confirmed as soon as it comes through.',
    );
  }

  if (became('status', 'cancelled')) {
    // A failed payment cancels the order too; that was announced above.
    if (after.paymentStatus === 'failed') return null;
    const back = [];
    if (wallet > 0) back.push(rupees(wallet) + ' goes back to your m2d wallet.');
    if (online && after.paymentStatus === 'paid' && payable > 0) {
      back.push(
        rupees(payable) + ' will be refunded to the account you paid from.',
      );
    }
    return say(
      'Order ' + id + ' cancelled',
      [
        after.cancelledBy === 'customer'
          ? 'You cancelled this order.'
          : 'The store cancelled this order.',
        ...back,
      ].join(' '),
    );
  }
  if (became('status', 'delivered')) {
    return say(
      'Order ' + id + ' delivered',
      courier ? 'Your parcel has reached you. Enjoy!'
        : 'Enjoy! Open the app to rate your delivery.',
    );
  }
  if (courier) {
    if (became('status', 'pickedUp')) {
      const tracking = after.trackingNumber;
      return say(
        'Order ' + id + ' shipped',
        'Your parcel is on its way' + (after.courierName ? ' with ' + after.courierName : '') + '.' +
          (tracking ? ' Tracking number ' + tracking + '.' : '') +
          ' It reaches you in ' + days + ' from the order date.',
      );
    }
    if (became('status', 'accepted')) {
      return say(
        'Order ' + id + ' packed',
        'Your parcel is packed and will be shipped soon.',
      );
    }
    return null;
  }
  if (became('status', 'pickedUp')) {
    return say(
      'Order ' + id + ' is out for delivery',
      (after.riderName || 'Your delivery partner') + ' is on the way to you.',
    );
  }

  // A delivery partner was given the order (first time, or a new one).
  const rider = after.riderName;
  if (
    typeof rider === 'string' &&
    rider !== '' &&
    rider !== was.riderName &&
    (after.status === 'placed' || after.status === 'accepted')
  ) {
    return say(
      'Delivery partner assigned',
      rider + ' will bring order ' + id + ' to you.',
    );
  }
  return null;
}

module.exports = { customerNotice };
