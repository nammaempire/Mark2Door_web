'use strict';

// Razorpay rules that do not need the network or the database, so they
// can be tested on their own: who may pay for an order and how much, and
// whether a payment or a webhook really came from Razorpay.

const crypto = require('crypto');

/** Paise the customer still has to pay online: the order less the wallet. */
function payablePaise(order) {
  const total = Number(order && order.totalPaise) || 0;
  const wallet = Number(order && order.walletAppliedPaise) || 0;
  const due = total - wallet;
  return due > 0 ? Math.round(due) : 0;
}

/**
 * Why [uid] cannot start an online payment for [order], or null when they
 * can. The amount always comes from the order saved in the database, never
 * from the phone, so it cannot be changed by a tampered app.
 */
function cannotPayReason(order, uid) {
  if (!order) return 'This order does not exist.';
  if (order.userId !== uid) return 'This order belongs to someone else.';
  if (order.paymentMethod !== 'online') {
    return 'This order is not paid online.';
  }
  if (order.status !== 'placed') return 'This order is no longer open.';
  if (order.paymentStatus === 'paid' || order.paymentStatus === 'refunded') {
    return 'This order is already paid.';
  }
  if (payablePaise(order) <= 0) return 'There is nothing to pay.';
  return null;
}

function hmac(secret, text) {
  return crypto.createHmac('sha256', secret).update(text).digest('hex');
}

/** Compares two signatures without leaking how much of them matched. */
function sameSignature(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

/**
 * True when Razorpay itself signed this payment. After a successful
 * checkout Razorpay hands the app a signature made from the Razorpay
 * order id, the payment id and the account's key secret. Only Razorpay
 * and this server know the secret, so an app cannot make one up.
 */
function validPaymentSignature(razorpayOrderId, paymentId, signature, secret) {
  if (!razorpayOrderId || !paymentId || !secret) return false;
  return sameSignature(
    hmac(secret, razorpayOrderId + '|' + paymentId),
    signature,
  );
}

/** True when a webhook call was signed with the webhook secret. */
function validWebhookSignature(rawBody, signature, secret) {
  if (!rawBody || !secret) return false;
  return sameSignature(hmac(secret, rawBody), signature);
}

/**
 * What a Razorpay webhook event asks for:
 * `{kind: 'paid', razorpayOrderId, paymentId, amountPaise}` when money was
 * captured, `{kind: 'refunded', paymentId}` when a refund went through,
 * or null for every other event.
 */
function webhookAction(event) {
  const type = event && event.event;
  const payload = (event && event.payload) || {};
  if (type === 'payment.captured' || type === 'order.paid') {
    const payment = payload.payment && payload.payment.entity;
    if (!payment || !payment.order_id || !payment.id) return null;
    return {
      kind: 'paid',
      razorpayOrderId: payment.order_id,
      paymentId: payment.id,
      amountPaise: Number(payment.amount) || 0,
    };
  }
  if (type === 'refund.processed') {
    const refund = payload.refund && payload.refund.entity;
    if (!refund || !refund.payment_id) return null;
    return { kind: 'refunded', paymentId: refund.payment_id };
  }
  return null;
}

/**
 * True when a cancelled order has online money on it that has not been
 * sent back yet. `refundRequestedAt` is set before Razorpay is called, so
 * the refund is never asked for twice.
 */
function needsRefund(order) {
  return Boolean(
    order &&
      order.status === 'cancelled' &&
      order.paymentMethod === 'online' &&
      order.paymentStatus === 'paid' &&
      typeof order.paymentId === 'string' &&
      order.paymentId !== '' &&
      !order.refundRequestedAt &&
      payablePaise(order) > 0,
  );
}

module.exports = {
  payablePaise,
  cannotPayReason,
  validPaymentSignature,
  validWebhookSignature,
  webhookAction,
  needsRefund,
};
