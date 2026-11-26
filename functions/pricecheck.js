'use strict';

// Works out what an order should cost from the store's own data, so an
// order saved by a tampered app with lower prices can be refused. Kept
// free of Firebase so it can be tested on its own.
//
// The app works out the same amounts (cart.dart, coupon.dart in the
// customer app). If the rules change there, change them here too.

/** Used when the admin has never saved the delivery settings. */
const DEFAULT_FEES = {
  deliveryFeePaise: 3000,
  freeDeliveryThresholdPaise: 49900,
  courierFeePaise: 6000,
  courierFreeAbovePaise: 99900,
};

function num(value, fallback) {
  const n = Number(value);
  return Number.isFinite(n) ? Math.round(n) : fallback;
}

/** Paise a coupon takes off an item total, as the app works it out. */
function couponDiscount(coupon, subtotalPaise, now) {
  if (!coupon || coupon.active === false || subtotalPaise <= 0) return 0;
  if (coupon.expiresAt != null && now > Number(coupon.expiresAt)) return 0;
  if (subtotalPaise < num(coupon.minOrderPaise, 0)) return 0;
  const value = num(coupon.value, 0);
  const percent = coupon.type !== 'flat';
  let off = percent ? Math.floor((subtotalPaise * value) / 100) : value;
  const cap = num(coupon.maxDiscountPaise, 0);
  if (percent && cap > 0 && off > cap) off = cap;
  if (off < 0) return 0;
  return off > subtotalPaise ? subtotalPaise : off;
}

/** Delivery, handling and rain charges for an item total. */
function feesFor(subtotalPaise, courier, settings) {
  const s = settings || {};
  if (courier) {
    const freeAbove = num(
      s.courierFreeAbovePaise,
      DEFAULT_FEES.courierFreeAbovePaise,
    );
    return subtotalPaise >= freeAbove
      ? 0
      : num(s.courierFeePaise, DEFAULT_FEES.courierFeePaise);
  }
  const freeAbove = num(
    s.freeDeliveryThresholdPaise,
    DEFAULT_FEES.freeDeliveryThresholdPaise,
  );
  const delivery =
    subtotalPaise >= freeAbove
      ? 0
      : num(s.deliveryFeePaise, DEFAULT_FEES.deliveryFeePaise);
  const handling = s.handlingFeeEnabled === true ? num(s.handlingFeePaise, 0) : 0;
  const rain = s.rainFeeEnabled === true ? num(s.rainFeePaise, 0) : 0;
  return delivery + handling + rain;
}

/**
 * Checks an order's total against the store's data.
 *
 * - [products]: `{productId: product data}` for the products in the order
 *   (a missing id means the product does not exist).
 * - [settings]: the store's delivery settings (`settings/store`).
 * - [coupon]: the coupon named on the order, or null.
 * - [offers]: the price slab offers, each `{minOrderPaise,
 *   offerPricePaise, productIds, active}`.
 *
 * Returns `{ok, expectedTotalPaise, reason}`. An order that pays the
 * expected amount or more is fine; only paying less is refused, so a
 * price that went down while the customer was ordering does no harm.
 */
function checkOrder(order, { products, settings, coupon, offers, now }) {
  const fail = (reason) => ({ ok: false, expectedTotalPaise: null, reason });
  if (!order || !Array.isArray(order.items) || order.items.length === 0) {
    return fail('The order has no items.');
  }

  let itemsPaise = 0; // ordinary items: what earns a slab offer
  const offerLines = [];
  for (const item of order.items) {
    const id = item && item.productId;
    const qty = Number(item && item.quantity);
    if (typeof id !== 'string' || id === '') return fail('An item has no product.');
    if (!Number.isInteger(qty) || qty < 1) {
      return fail('An item has a quantity that is not allowed.');
    }
    const product = products && products[id];
    if (!product) return fail('An item is not a product of the store.');
    if (item.offer === true) {
      offerLines.push({ id, qty, pricePaise: num(item.pricePaise, 0), product });
    } else {
      itemsPaise += num(product.pricePaise, 0) * qty;
    }
  }

  // The offer product: one unit, from an offer the items have earned.
  let offerPaise = 0;
  if (offerLines.length > 1) return fail('More than one offer product.');
  if (offerLines.length === 1) {
    const line = offerLines[0];
    if (line.qty !== 1) return fail('More than one unit of the offer product.');
    const earned = (offers || []).some(
      (o) =>
        o &&
        o.active !== false &&
        Array.isArray(o.productIds) &&
        o.productIds.includes(line.id) &&
        num(o.offerPricePaise, -1) === line.pricePaise &&
        itemsPaise >= num(o.minOrderPaise, Infinity),
    );
    // Not a valid offer: the product counts at its usual price.
    offerPaise = earned ? line.pricePaise : num(line.product.pricePaise, 0);
  }

  const subtotal = itemsPaise + offerPaise;
  const courier = order.deliveryType === 'courier';
  const fees = feesFor(subtotal, courier, settings);
  const discount =
    typeof order.couponCode === 'string' && order.couponCode !== ''
      ? couponDiscount(coupon, subtotal, now)
      : 0;
  const expected = subtotal + fees - discount;

  const total = num(order.totalPaise, NaN);
  if (!Number.isFinite(total)) return fail('The order has no total.');
  const wallet = num(order.walletAppliedPaise, 0);
  if (wallet < 0 || wallet > total) {
    return { ok: false, expectedTotalPaise: expected, reason: 'The wallet amount is not allowed.' };
  }
  if (total < expected) {
    return {
      ok: false,
      expectedTotalPaise: expected,
      reason:
        'The order total is ' + total + ' paise but the store prices come to ' +
        expected + ' paise.',
    };
  }
  return { ok: true, expectedTotalPaise: expected, reason: null };
}

module.exports = { checkOrder, couponDiscount, feesFor, DEFAULT_FEES };
