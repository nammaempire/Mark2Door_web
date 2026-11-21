'use strict';

const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const { newAssignment, cancelledForRider, displayId } = require('./notify');
const { customerNotice } = require('./customer');
const { quantities, pendingWork, hasWork, nextStock } = require('./stock');

admin.initializeApp();

const db = () => admin.firestore();
const orderChanges = functions.firestore.document('orders/{orderId}');

/**
 * Sends one push notification to the phone saved at [tokenPath]
 * (`{token}`). Does nothing when no phone is saved there. A token Google
 * reports as dead is removed so it is not tried again.
 */
async function push(tokenPath, note, data, androidNotification) {
  const tokenRef = db().doc(tokenPath);
  const snap = await tokenRef.get();
  const token = snap.exists ? snap.data().token : null;
  if (!token) {
    functions.logger.info('No phone registered at', tokenPath);
    return;
  }
  try {
    await admin.messaging().send({
      token,
      notification: { title: note.title, body: note.body },
      data,
      android: { priority: 'high', notification: androidNotification },
    });
  } catch (error) {
    const code = error && error.code;
    if (
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token'
    ) {
      await tokenRef.delete();
      functions.logger.info('Removed dead token at', tokenPath);
    } else {
      functions.logger.error('Could not notify', tokenPath, error);
    }
  }
}

/**
 * Tells a delivery partner when the admin assigns them an order, and when
 * an order they are handling is cancelled.
 *
 * The delivery app saves each rider's phone token in
 * `rider_tokens/{10-digit phone}`.
 */
exports.notifyRiderOfNewOrder = orderChanges.onWrite(async (change, context) => {
  const before = change.before.exists ? change.before.data() : null;
  const after = change.after.exists ? change.after.data() : null;
  const orderId = context.params.orderId;
  const assigned = newAssignment(before, after, orderId);
  const note = assigned || cancelledForRider(before, after, orderId);
  if (!note) return null;

  await push(
    'rider_tokens/' + note.phone,
    note,
    { orderId, type: assigned ? 'new_order' : 'order_cancelled' },
    // The delivery app creates this channel with its own alert sound
    // (res/raw/order_alert.ogg). `sound` covers Android 7 and older.
    {
      channelId: 'new_orders_v2',
      sound: 'order_alert',
      defaultVibrateTimings: true,
    },
  );
  return null;
});

/**
 * Tells the customer about their order: placed, payment pending or
 * failed, refund sent, delivery partner assigned, out for delivery,
 * delivered and cancelled.
 *
 * The customer app saves each customer's phone token in
 * `customer_tokens/{uid}`.
 */
exports.notifyCustomerOfOrder = orderChanges.onWrite(
  async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    const orderId = context.params.orderId;
    const note = customerNotice(before, after, orderId);
    if (!note) return null;

    await push(
      'customer_tokens/' + note.uid,
      note,
      { orderId, type: 'order_update' },
      { sound: 'default', defaultVibrateTimings: true },
    );
    return null;
  },
);

/**
 * Keeps stock, the wallet and once-only coupons right as orders come and
 * go:
 *
 * - A new order takes its items out of each product's `stockQty`.
 * - A cancelled order puts them back, returns any m2d wallet money that
 *   was used on it, and frees a once-only coupon to be used again.
 *
 * Products without a `stockQty` number are not counted and are left
 * alone. Each step is recorded on the order (`stockTaken`,
 * `stockReturned`, `walletRefunded`), so nothing is ever done twice, also
 * not by the admin web, which can do the wallet step as well.
 */
exports.keepStockAndWallet = orderChanges.onWrite(async (change, context) => {
  const after = change.after.exists ? change.after.data() : null;
  if (!after) return null;
  const orderId = context.params.orderId;
  const orderRef = change.after.ref;

  if (hasWork(pendingWork(after))) {
    await db().runTransaction(async (tx) => {
      // Read again inside the transaction: this function also runs for
      // its own writes, and two runs must not both do the work.
      const fresh = (await tx.get(orderRef)).data();
      const work = pendingWork(fresh);
      if (!hasWork(work)) return;

      const qty = quantities(fresh);
      const ids = Object.keys(qty);
      const moveStock = work.takeStock || work.returnStock;
      // All reads come before any write, as transactions require.
      const products = moveStock
        ? await Promise.all(
            ids.map((id) => tx.get(db().collection('products').doc(id))),
          )
        : [];
      const walletRef = work.refundWallet
        ? db().collection('wallets').doc(fresh.userId)
        : null;
      const wallet = walletRef ? (await tx.get(walletRef)).data() || {} : null;

      const update = {};
      if (moveStock) {
        const sign = work.takeStock ? -1 : 1;
        products.forEach((snap, i) => {
          if (!snap.exists) return;
          const next = nextStock(snap.data().stockQty, sign * qty[ids[i]]);
          if (next !== null) tx.update(snap.ref, { stockQty: next });
        });
        if (work.takeStock) update.stockTaken = true;
        else update.stockReturned = true;
      }
      if (work.skipStock) {
        update.stockTaken = true;
        update.stockReturned = true;
      }
      if (walletRef) {
        const now = Date.now();
        const amount = Number(fresh.walletAppliedPaise) || 0;
        tx.set(
          walletRef,
          {
            balancePaise: (Number(wallet.balancePaise) || 0) + amount,
            updatedAt: now,
          },
          { merge: true },
        );
        tx.set(walletRef.collection('transactions').doc(), {
          amountPaise: amount,
          type: 'order_refund',
          note: 'Returned from cancelled order ' + displayId(orderId),
          orderId,
          createdAt: now,
        });
        update.walletRefunded = true;
      }
      tx.update(orderRef, update);
    });
  }

  // A cancelled order gives its once-only coupon back to the customer.
  const before = change.before.exists ? change.before.data() : null;
  const justCancelled =
    after.status === 'cancelled' && (!before || before.status !== 'cancelled');
  const code = after.couponCode;
  if (
    justCancelled &&
    typeof code === 'string' &&
    code !== '' &&
    !code.includes('/') &&
    typeof after.userId === 'string' &&
    after.userId !== ''
  ) {
    const useRef = db().doc('coupons/' + code + '/uses/' + after.userId);
    const use = await useRef.get();
    // Only if it was this order that used the coupon.
    if (use.exists && use.data().orderId === orderId) await useRef.delete();
  }
  return null;
});
