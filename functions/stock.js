'use strict';

// Works out what an order change means for stock, the wallet and coupons.
// Kept free of Firebase so it can be tested on its own.

/**
 * Units of each product in the order, as `{productId: quantity}`. Lines
 * for the same product are added together.
 */
function quantities(order) {
  const out = {};
  for (const item of Array.isArray(order.items) ? order.items : []) {
    const id = item && item.productId;
    const qty = Number(item && item.quantity) || 0;
    if (typeof id !== 'string' || id === '' || qty <= 0) continue;
    out[id] = (out[id] || 0) + qty;
  }
  return out;
}

/**
 * What still has to be done for this order, read from the order itself so
 * that running twice changes nothing:
 *
 * - `takeStock`: the order is new and its stock has not been taken yet.
 * - `returnStock`: it was cancelled after its stock was taken.
 * - `refundWallet`: it was cancelled with wallet money on it.
 * - `skipStock`: it was cancelled before its stock was ever taken, so
 *   there is nothing to take or return; just mark it as handled.
 */
function pendingWork(order) {
  if (!order) return {};
  const cancelled = order.status === 'cancelled';
  const taken = order.stockTaken === true;
  const returned = order.stockReturned === true;
  return {
    takeStock: !cancelled && !taken,
    skipStock: cancelled && !taken,
    returnStock: cancelled && taken && !returned,
    refundWallet:
      cancelled &&
      (Number(order.walletAppliedPaise) || 0) > 0 &&
      order.walletRefunded !== true &&
      typeof order.userId === 'string' &&
      order.userId !== '',
  };
}

/** True when there is anything in [work] to do. */
function hasWork(work) {
  return Boolean(
    work.takeStock || work.skipStock || work.returnStock || work.refundWallet,
  );
}

/**
 * New stock count for a product after [delta] units leave (negative) or
 * come back (positive). Products the admin does not count (no number
 * stored) are left alone, shown by returning null. Never goes below zero.
 */
function nextStock(current, delta) {
  if (typeof current !== 'number' || !Number.isFinite(current)) return null;
  const next = current + delta;
  return next < 0 ? 0 : next;
}

/**
 * Which stock count an order moves, for a business with several stores.
 *
 * A product can keep stock per store under `storeStock.{storeId}`. An
 * order served by a store ([storeId] set) moves that store's count when
 * the product has an entry for it; otherwise, and for a business with one
 * shop, it moves the product's own `stockQty`.
 *
 * Returns the field to update and the number in it now (not a number
 * when that stock is not counted).
 */
function stockTarget(product, storeId) {
  const perStore = product && product.storeStock;
  if (
    typeof storeId === 'string' &&
    storeId !== '' &&
    perStore &&
    typeof perStore === 'object' &&
    perStore[storeId] &&
    typeof perStore[storeId] === 'object'
  ) {
    return {
      field: 'storeStock.' + storeId + '.stockQty',
      current: perStore[storeId].stockQty,
    };
  }
  return { field: 'stockQty', current: product ? product.stockQty : undefined };
}

module.exports = { quantities, pendingWork, hasWork, nextStock, stockTarget };
