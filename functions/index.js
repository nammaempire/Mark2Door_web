'use strict';

const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const { newAssignment, cancelledForRider, displayId } = require('./notify');
const { customerNotice } = require('./customer');
const { TOPIC, announcementMessage } = require('./announce');
const {
  quantities,
  pendingWork,
  hasWork,
  nextStock,
  stockTarget,
} = require('./stock');
const { checkOrder } = require('./pricecheck');
const { REWARD_PAISE, rewardFor, needsRewardCheck } = require('./rewards');
const {
  changes: statChanges,
  totalsFor,
  customerChanges,
  customerTotalsFor,
} = require('./stats');
const {
  payablePaise,
  cannotPayReason,
  validPaymentSignature,
  validWebhookSignature,
  webhookAction,
  needsRefund,
  paymentProblem,
} = require('./payments');

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
 * `stockReturned`, `walletRefunded`), so nothing is ever done twice.
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
          // The serving store's own count, when the product has one.
          const target = stockTarget(snap.data(), fresh.storeId);
          const next = nextStock(target.current, sign * qty[ids[i]]);
          if (next !== null) tx.update(snap.ref, { [target.field]: next });
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

// ---------------------------------------------------------------------
// Invite rewards
// ---------------------------------------------------------------------

/**
 * Pays the inviter's reward when an invited customer's first order is
 * delivered. This used to be done by the admin web, and only while the
 * main admin had it open; done here it happens within seconds of the
 * delivery, whoever is signed in.
 *
 * Each delivered order is looked at once (`referralChecked` on the
 * order), and each invitation is settled once (its status moves on from
 * `joined`), so a reward is never paid twice.
 */
exports.payInviteReward = orderChanges.onWrite(async (change) => {
  const after = change.after.exists ? change.after.data() : null;
  if (!needsRewardCheck(after)) return null;
  const orderRef = change.after.ref;
  const userId = after.userId;

  // Only a customer's first delivered order can earn their inviter a
  // reward. Looked up before the transaction, which cannot run queries.
  const delivered = await db()
    .collection('orders')
    .where('userId', '==', userId)
    .where('status', '==', 'delivered')
    .limit(2)
    .get();
  const firstDelivered = delivered.docs.every((d) => d.id === orderRef.id);

  await db().runTransaction(async (tx) => {
    // Read again inside the transaction, so two runs cannot both pay.
    const fresh = (await tx.get(orderRef)).data();
    if (!needsRewardCheck(fresh)) return;
    const now = Date.now();
    const referralRef = db().collection('referrals').doc(userId);
    const referral = (await tx.get(referralRef)).data();

    if (referral && referral.status === 'joined') {
      const referrer =
        typeof referral.referrerUid === 'string' ? referral.referrerUid : '';
      if (!firstDelivered || referrer === '' || referrer.includes('/')) {
        tx.update(referralRef, { status: 'ineligible', completedAt: now });
      } else {
        const walletRef = db().collection('wallets').doc(referrer);
        const reward = rewardFor((await tx.get(walletRef)).data());
        tx.set(
          walletRef,
          {
            balancePaise: reward.balancePaise,
            successfulInvites: reward.invites,
            rewardedMilestones: reward.rewardedMilestones,
            updatedAt: now,
          },
          { merge: true },
        );
        for (let i = 0; i < reward.due; i++) {
          tx.set(walletRef.collection('transactions').doc(), {
            amountPaise: REWARD_PAISE,
            type: 'referral_reward',
            note: reward.note,
            orderId: orderRef.id,
            createdAt: now + i,
          });
        }
        tx.update(referralRef, { status: 'ordered', completedAt: now });
      }
    }
    tx.update(orderRef, { referralChecked: true });
  });
  return null;
});

// ---------------------------------------------------------------------
// Daily sales totals
// ---------------------------------------------------------------------
//
// `stats_daily/{day}__{store}` holds one day's totals for one store. The
// admin's dashboard and reports read these instead of every order, so
// they stay correct and quick however many orders there are.

/** Writes [docs] (`{docId: {day, storeId, totals, items}}`) as additions. */
function addToDays(tx, docs) {
  const inc = admin.firestore.FieldValue.increment;
  for (const [docId, change] of Object.entries(docs)) {
    const data = { day: change.day, storeId: change.storeId };
    for (const [key, value] of Object.entries(change.totals)) {
      data[key] = inc(value);
    }
    const items = {};
    for (const [name, value] of Object.entries(change.items)) {
      items[name] = { q: inc(value.q), p: inc(value.p) };
    }
    if (Object.keys(items).length) data.items = items;
    tx.set(db().collection('stats_daily').doc(docId), data, { merge: true });
  }
}

/** Writes customer records (see stats.js) as additions. */
function addToCustomers(tx, docs) {
  const inc = admin.firestore.FieldValue.increment;
  for (const [docId, change] of Object.entries(docs)) {
    tx.set(
      db().collection('stats_customers').doc(docId),
      {
        period: change.period,
        storeId: change.storeId,
        phone: change.phone,
        orders: inc(change.orders),
        spentPaise: inc(change.spentPaise),
        ...(change.latest || {}),
      },
      { merge: true },
    );
  }
}

/** Keeps the day and customer totals in step with every order change. */
exports.keepDailyTotals = orderChanges.onWrite(async (change, context) => {
  const before = change.before.exists ? change.before.data() : null;
  const after = change.after.exists ? change.after.data() : null;
  const docs = statChanges(before, after);
  const customers = customerChanges(before, after);
  // Most changes (a rider accepting, a photo) do not move any total.
  if (Object.keys(docs).length === 0 && Object.keys(customers).length === 0) {
    return null;
  }
  // A change can be delivered twice; the marker makes it count once.
  const marker = db().collection('stats_events').doc(context.eventId);
  await db().runTransaction(async (tx) => {
    if ((await tx.get(marker)).exists) return;
    addToDays(tx, docs);
    addToCustomers(tx, customers);
    tx.create(marker, { at: Date.now() });
  });
  return null;
});

/** Clears the once-only markers, which are needed for a short time only. */
exports.cleanDailyTotalMarkers = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const cutoff = Date.now() - 3 * 24 * 60 * 60 * 1000;
    for (let round = 0; round < 20; round++) {
      const old = await db()
        .collection('stats_events')
        .where('at', '<', cutoff)
        .limit(400)
        .get();
      if (old.empty) break;
      const batch = db().batch();
      old.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }
    return null;
  });

/**
 * Works every day's totals out again from all the orders. The main admin
 * starts it from the Reports page by adding a `stats_jobs` record (the
 * rules let nobody else add one): once after this is first deployed,
 * because orders placed before then were never counted, and again if the
 * totals ever look wrong. The result is written back onto the record.
 */
exports.rebuildDailyTotals = functions
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .firestore.document('stats_jobs/{jobId}')
  .onCreate(async (snap) => {
    try {
      const result = await rebuildDailyTotals();
      await snap.ref.update({ status: 'done', finishedAt: Date.now(), ...result });
    } catch (error) {
      functions.logger.error('Rebuilding the daily totals failed', error);
      await snap.ref.update({ status: 'failed', finishedAt: Date.now() });
    }
    return null;
  });

async function rebuildDailyTotals() {
    // Read every order, a page at a time.
    const orders = [];
    let last = null;
    for (;;) {
      let query = db()
        .collection('orders')
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(500);
      if (last) query = query.startAfter(last);
      const page = await query.get();
      if (page.empty) break;
      page.docs.forEach((d) => orders.push(d.data()));
      last = page.docs[page.docs.length - 1];
    }
    const fresh = totalsFor(orders);

    // Replace what is stored: remove days that no longer have orders,
    // then write each day in full.
    const existing = await db().collection('stats_daily').select().get();
    const writes = [];
    existing.docs.forEach((d) => {
      if (!fresh[d.id]) writes.push((batch) => batch.delete(d.ref));
    });
    for (const [docId, day] of Object.entries(fresh)) {
      writes.push((batch) =>
        batch.set(db().collection('stats_daily').doc(docId), {
          day: day.day,
          storeId: day.storeId,
          ...day.totals,
          items: day.items,
        }),
      );
    }
    // The customer records, the same way.
    const customers = customerTotalsFor(orders);
    const oldCustomers = await db().collection('stats_customers').select().get();
    oldCustomers.docs.forEach((d) => {
      if (!customers[d.id]) writes.push((batch) => batch.delete(d.ref));
    });
    for (const [docId, c] of Object.entries(customers)) {
      writes.push((batch) =>
        batch.set(db().collection('stats_customers').doc(docId), {
          period: c.period,
          storeId: c.storeId,
          phone: c.phone,
          orders: c.orders,
          spentPaise: c.spentPaise,
          ...(c.latest || {}),
        }),
      );
    }
    for (let i = 0; i < writes.length; i += 400) {
      const batch = db().batch();
      writes.slice(i, i + 400).forEach((write) => write(batch));
      await batch.commit();
    }
    return { orders: orders.length, days: Object.keys(fresh).length };
}

// ---------------------------------------------------------------------
// Price check
// ---------------------------------------------------------------------
//
// The customer app works out an order's total and saves the order itself.
// The server works the total out again from the store's own prices,
// charges, coupon and offers. An order that pays less than that is
// cancelled, so a tampered app cannot order at made-up prices.

/** Reads what [order] should cost and compares it with what it says. */
async function priceCheck(order) {
  const ids = [
    ...new Set(
      (Array.isArray(order.items) ? order.items : [])
        .map((i) => i && i.productId)
        .filter((id) => typeof id === 'string' && id !== '' && !id.includes('/')),
    ),
  ];
  const code = order.couponCode;
  const hasCoupon =
    typeof code === 'string' && code !== '' && !code.includes('/');
  const [productSnaps, settingsSnap, couponSnap, offerSnaps] = await Promise.all([
    Promise.all(ids.map((id) => db().collection('products').doc(id).get())),
    db().doc('settings/store').get(),
    hasCoupon ? db().doc('coupons/' + code).get() : null,
    db().collection('slab_offers').get(),
  ]);
  const products = {};
  productSnaps.forEach((snap, i) => {
    if (snap.exists) products[ids[i]] = snap.data();
  });
  return checkOrder(order, {
    products,
    settings: settingsSnap.exists ? settingsSnap.data() : {},
    coupon: couponSnap && couponSnap.exists ? couponSnap.data() : null,
    offers: offerSnaps.docs.map((d) => d.data()),
    // A coupon is judged at the time the order was placed.
    now: Number(order.createdAt) || Date.now(),
  });
}

/**
 * Cancels [ref] because its total is below the store's prices. Stock,
 * wallet money and a once-only coupon come back through the usual
 * cancelled-order steps.
 */
async function cancelForPrice(ref, result) {
  functions.logger.warn('Order failed the price check', {
    orderId: ref.id,
    reason: result.reason,
  });
  await db().runTransaction(async (tx) => {
    const fresh = (await tx.get(ref)).data();
    // Leave an order that is already paid, finished or cancelled alone.
    if (!fresh || fresh.status !== 'placed' || fresh.paymentStatus === 'paid') {
      return;
    }
    tx.update(ref, {
      status: 'cancelled',
      cancelledBy: 'store',
      cancelReason: 'price_check',
      priceCheck: 'failed',
      priceCheckNote: result.reason,
      priceCheckExpectedPaise: result.expectedTotalPaise,
    });
  });
}

/** Every new order has its total checked against the store's prices. */
exports.checkOrderPrices = orderChanges.onCreate(async (snap) => {
  const order = snap.data();
  if (!order || order.status === 'cancelled') return null;
  let result;
  try {
    result = await priceCheck(order);
  } catch (error) {
    // A failed read must not cancel a real customer's order.
    functions.logger.error('Price check could not run', error);
    return null;
  }
  if (!result.ok) await cancelForPrice(snap.ref, result);
  return null;
});

// ---------------------------------------------------------------------
// Online payments with Razorpay
// ---------------------------------------------------------------------
//
// The key secret never leaves this server. Set the three values once:
//   firebase functions:secrets:set RAZORPAY_KEY_ID
//   firebase functions:secrets:set RAZORPAY_KEY_SECRET
//   firebase functions:secrets:set RAZORPAY_WEBHOOK_SECRET
// Test keys (rzp_test_...) take no real money; swap in live keys to go live.

const RAZORPAY_SECRETS = [
  'RAZORPAY_KEY_ID',
  'RAZORPAY_KEY_SECRET',
  'RAZORPAY_WEBHOOK_SECRET',
];
const withRazorpay = functions.runWith({ secrets: RAZORPAY_SECRETS });

/** Calls the Razorpay API. Throws with Razorpay's own message on failure. */
async function razorpay(path, body) {
  const auth = Buffer.from(
    process.env.RAZORPAY_KEY_ID + ':' + process.env.RAZORPAY_KEY_SECRET,
  ).toString('base64');
  // With no body, the call reads (GET) instead of creating (POST).
  const response = await fetch('https://api.razorpay.com/v1' + path, {
    method: body === undefined ? 'GET' : 'POST',
    headers: {
      Authorization: 'Basic ' + auth,
      'Content-Type': 'application/json',
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const json = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message =
      (json && json.error && json.error.description) ||
      'Razorpay answered ' + response.status;
    throw new Error(message);
  }
  return json;
}

function signedInUid(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Sign in to pay for an order.',
    );
  }
  return context.auth.uid;
}

/**
 * Step 1 of paying online, called by the customer app: opens a Razorpay
 * order for the amount still due on the customer's own order and returns
 * what the app needs to show Razorpay's payment screen. The amount comes
 * from the saved order, not from the app.
 */
exports.createPaymentOrder = withRazorpay.https.onCall(
  async (data, context) => {
    const uid = signedInUid(context);
    const orderId = data && data.orderId;
    if (typeof orderId !== 'string' || orderId === '') {
      throw new functions.https.HttpsError('invalid-argument', 'No order.');
    }
    const ref = db().collection('orders').doc(orderId);
    const order = (await ref.get()).data();
    const problem = cannotPayReason(order, uid);
    if (problem) {
      throw new functions.https.HttpsError('failed-precondition', problem);
    }
    const amount = payablePaise(order);

    // No payment is opened for an order priced below the store's prices.
    const priced = await priceCheck(order);
    if (!priced.ok) {
      await cancelForPrice(ref, priced);
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Prices have changed. Please place the order again.',
      );
    }

    // Paying again after a failed try reuses the same Razorpay order.
    let razorpayOrderId = order.razorpayOrderId;
    if (!razorpayOrderId || order.razorpayAmountPaise !== amount) {
      try {
        const created = await razorpay('/orders', {
          amount,
          currency: 'INR',
          receipt: orderId,
          notes: { orderId, displayId: displayId(orderId) },
        });
        razorpayOrderId = created.id;
      } catch (error) {
        functions.logger.error('Could not open a Razorpay order', error);
        throw new functions.https.HttpsError(
          'unavailable',
          'Could not start the payment. Please try again.',
        );
      }
      await ref.update({ razorpayOrderId, razorpayAmountPaise: amount });
    }
    return {
      keyId: process.env.RAZORPAY_KEY_ID,
      razorpayOrderId,
      amountPaise: amount,
    };
  },
);

/**
 * Step 2, called by the customer app after Razorpay reports success:
 * checks Razorpay's signature and only then marks the order paid. An app
 * cannot mark its own order paid; the database rules refuse it.
 */
exports.verifyPayment = withRazorpay.https.onCall(async (data, context) => {
  const uid = signedInUid(context);
  const orderId = data && data.orderId;
  const paymentId = data && data.razorpayPaymentId;
  const signature = data && data.razorpaySignature;
  if (typeof orderId !== 'string' || orderId === '') {
    throw new functions.https.HttpsError('invalid-argument', 'No order.');
  }
  const ref = db().collection('orders').doc(orderId);
  const order = (await ref.get()).data();
  if (!order || order.userId !== uid) {
    throw new functions.https.HttpsError('not-found', 'Order not found.');
  }
  if (order.paymentStatus === 'paid') return { status: 'paid' };
  if (
    !validPaymentSignature(
      order.razorpayOrderId,
      paymentId,
      signature,
      process.env.RAZORPAY_KEY_SECRET,
    )
  ) {
    functions.logger.warn('Payment signature did not match for', orderId);
    throw new functions.https.HttpsError(
      'permission-denied',
      'This payment could not be confirmed.',
    );
  }
  // Ask Razorpay what really happened to this payment. A success is
  // accepted only if Razorpay records it as paid, for this order and for
  // the right amount.
  let payment;
  try {
    payment = await razorpay('/payments/' + encodeURIComponent(paymentId));
  } catch (error) {
    // Razorpay could not be asked just now. The webhook settles it; the
    // app shows the order as pending until then.
    functions.logger.error('Could not look up payment', paymentId, error);
    throw new functions.https.HttpsError(
      'unavailable',
      'The payment is being confirmed.',
    );
  }
  const problem = paymentProblem(payment, order);
  if (problem) {
    functions.logger.warn('Payment refused for', orderId, problem);
    throw new functions.https.HttpsError('permission-denied', problem);
  }
  await ref.update({
    paymentStatus: 'paid',
    paymentId,
    // How it was paid, for the store: "upi", "card", "netbanking"...
    paidVia: payment.method || null,
    paidVpa: payment.vpa || null,
  });
  functions.logger.info(
    'Order paid',
    orderId,
    paymentId,
    payment.method,
    payment.status,
  );
  return { status: 'paid' };
});

/**
 * Razorpay calls this address itself when money is captured or a refund
 * goes through. It settles payments the app could not confirm, for
 * example when the customer closed the app or lost signal right after
 * paying. Add the function's URL as a webhook in the Razorpay dashboard,
 * with the events payment.captured, order.paid and refund.processed.
 */
exports.razorpayWebhook = withRazorpay.https.onRequest(async (req, res) => {
  const signature = req.get('x-razorpay-signature');
  const raw = req.rawBody ? req.rawBody.toString('utf8') : '';
  if (
    !validWebhookSignature(raw, signature, process.env.RAZORPAY_WEBHOOK_SECRET)
  ) {
    functions.logger.warn('Webhook with a bad signature was refused');
    res.status(400).send('bad signature');
    return;
  }
  const action = webhookAction(req.body);
  try {
    if (action && action.kind === 'paid') {
      const found = await db()
        .collection('orders')
        .where('razorpayOrderId', '==', action.razorpayOrderId)
        .limit(1)
        .get();
      if (!found.empty) {
        const doc = found.docs[0];
        const order = doc.data();
        if (
          order.paymentStatus !== 'paid' &&
          order.paymentStatus !== 'refunded' &&
          action.amountPaise === payablePaise(order)
        ) {
          // If the app already gave up and cancelled the order, the
          // refund function below sends this money straight back.
          await doc.ref.update({
            paymentStatus: 'paid',
            paymentId: action.paymentId,
          });
        }
      }
    } else if (action && action.kind === 'refunded') {
      const found = await db()
        .collection('orders')
        .where('paymentId', '==', action.paymentId)
        .limit(1)
        .get();
      if (!found.empty && found.docs[0].data().paymentStatus !== 'refunded') {
        await found.docs[0].ref.update({ paymentStatus: 'refunded' });
      }
    }
  } catch (error) {
    // Answer with an error so that Razorpay tries again later.
    functions.logger.error('Webhook could not be applied', error);
    res.status(500).send('try again');
    return;
  }
  res.status(200).send('ok');
});

/**
 * Sends the money back when an order that was paid online is cancelled,
 * by the customer, the store, or because the payment arrived after the
 * app had given up. If Razorpay refuses, the reason is saved on the order
 * as `refundError` and the store can refund from the Razorpay dashboard.
 */
exports.refundCancelledOrder = withRazorpay.firestore
  .document('orders/{orderId}')
  .onWrite(async (change, context) => {
    const after = change.after.exists ? change.after.data() : null;
    if (!needsRefund(after)) return null;
    const ref = change.after.ref;

    // Claim the refund first, so two runs cannot both ask for it.
    const claimed = await db().runTransaction(async (tx) => {
      const fresh = (await tx.get(ref)).data();
      if (!needsRefund(fresh)) return null;
      tx.update(ref, { refundRequestedAt: Date.now() });
      return fresh;
    });
    if (!claimed) return null;

    try {
      const refund = await razorpay(
        '/payments/' + claimed.paymentId + '/refund',
        {
          amount: payablePaise(claimed),
          notes: { orderId: context.params.orderId },
        },
      );
      await ref.update({ refundId: refund.id, paymentStatus: 'refunded' });
    } catch (error) {
      functions.logger.error(
        'Refund failed for',
        context.params.orderId,
        error,
      );
      await ref.update({ refundError: String(error.message || error) });
    }
    return null;
  });

/**
 * Sends a notification the store typed in the admin web ("Notify
 * customers") to every customer phone. Runs when the admin web adds a
 * document to `announcements`, and records on it whether it was sent.
 */
exports.sendAnnouncement = functions.firestore
  .document('announcements/{id}')
  .onCreate(async (snap) => {
    const note = announcementMessage(snap.data());
    if (!note) {
      await snap.ref.update({ status: 'failed', error: 'Empty message' });
      return null;
    }
    try {
      await admin.messaging().send({
        topic: TOPIC,
        notification: note,
        data: { type: 'offer' },
        android: {
          priority: 'high',
          notification: { sound: 'default', defaultVibrateTimings: true },
        },
      });
      await snap.ref.update({ status: 'sent', sentAt: Date.now() });
    } catch (error) {
      functions.logger.error('Could not send announcement', error);
      await snap.ref.update({
        status: 'failed',
        error: String((error && error.message) || error),
      });
    }
    return null;
  });
