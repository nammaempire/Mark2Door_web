'use strict';

// Running sales totals, one record per day and store, kept up to date by
// the server each time an order changes. The admin's dashboard and
// reports read these few records instead of every order, so the numbers
// stay right however many orders there are.
//
// The rules here match the admin console's (order.dart, sales_report.dart):
// - a cancelled order counts only as cancelled;
// - an online order that is not paid yet counts only as unpaid;
// - every other order counts as revenue: cash orders from the moment they
//   are placed, online orders once paid.
//
// Kept free of Firebase so it can be tested on its own.

const IST_OFFSET_MS = 330 * 60 * 1000;

/** The calendar day in India of a time in epoch milliseconds. */
function dayOf(ms) {
  return new Date(Number(ms) + IST_OFFSET_MS).toISOString().slice(0, 10);
}

function paise(value) {
  const n = Number(value);
  return Number.isFinite(n) ? Math.round(n) : 0;
}

/** The record an order's day belongs to. */
function dayDocId(day, storeId) {
  return day + '__' + (storeId || 'none');
}

/**
 * What one order adds to its day's totals; null for no order (or one with
 * no usable date).
 */
function contribution(order) {
  if (!order) return null;
  const at = Number(order.createdAt);
  if (!Number.isFinite(at) || at <= 0) return null;
  const storeId =
    typeof order.storeId === 'string' && !order.storeId.includes('/')
      ? order.storeId
      : '';
  const day = dayOf(at);
  const out = {
    docId: dayDocId(day, storeId),
    day,
    storeId,
    totals: {
      orders: 1,
      revenueOrders: 0,
      revenuePaise: 0,
      cancelledOrders: 0,
      unpaidOrders: 0,
      codPaise: 0,
      onlinePaise: 0,
      deliveryFeesPaise: 0,
    },
    // Product name -> {q: units, p: paise}, for the best-seller list.
    items: {},
  };
  const t = out.totals;
  if (order.status === 'cancelled') {
    t.cancelledOrders = 1;
    return out;
  }
  const cod = order.paymentMethod === 'cod';
  if (!cod && order.paymentStatus !== 'paid') {
    t.unpaidOrders = 1;
    return out;
  }
  const total = paise(order.totalPaise);
  t.revenueOrders = 1;
  t.revenuePaise = total;
  t.deliveryFeesPaise = paise(order.deliveryFeePaise);
  if (cod) t.codPaise = total;
  else t.onlinePaise = total;
  for (const item of Array.isArray(order.items) ? order.items : []) {
    const name = item && typeof item.name === 'string' ? item.name : '';
    if (name === '') continue;
    const qty = paise(item.quantity);
    const line = paise(item.pricePaise) * qty;
    const entry = out.items[name] || { q: 0, p: 0 };
    entry.q += qty;
    entry.p += line;
    out.items[name] = entry;
  }
  return out;
}

/**
 * What must change in the day records when an order goes from [before] to
 * [after] (either may be null). Returns `{docId: {day, storeId, totals,
 * items}}` holding only amounts to add (negative to take away); records
 * with nothing to change are left out.
 */
function changes(before, after) {
  const merged = {};
  const apply = (c, sign) => {
    if (!c) return;
    const m =
      merged[c.docId] ||
      (merged[c.docId] = { day: c.day, storeId: c.storeId, totals: {}, items: {} });
    for (const [key, value] of Object.entries(c.totals)) {
      m.totals[key] = (m.totals[key] || 0) + sign * value;
    }
    for (const [name, value] of Object.entries(c.items)) {
      const e = m.items[name] || (m.items[name] = { q: 0, p: 0 });
      e.q += sign * value.q;
      e.p += sign * value.p;
    }
  };
  apply(contribution(before), -1);
  apply(contribution(after), 1);

  const out = {};
  for (const [docId, m] of Object.entries(merged)) {
    const totals = {};
    for (const [key, value] of Object.entries(m.totals)) {
      if (value !== 0) totals[key] = value;
    }
    const items = {};
    for (const [name, value] of Object.entries(m.items)) {
      if (value.q !== 0 || value.p !== 0) items[name] = value;
    }
    if (Object.keys(totals).length || Object.keys(items).length) {
      out[docId] = { day: m.day, storeId: m.storeId, totals, items };
    }
  }
  return out;
}

/** Every day's full totals for a list of orders: used to rebuild them. */
function totalsFor(orders) {
  const out = {};
  for (const order of orders) {
    const c = contribution(order);
    if (!c) continue;
    const m =
      out[c.docId] ||
      (out[c.docId] = { day: c.day, storeId: c.storeId, totals: {}, items: {} });
    for (const [key, value] of Object.entries(c.totals)) {
      m.totals[key] = (m.totals[key] || 0) + value;
    }
    for (const [name, value] of Object.entries(c.items)) {
      const e = m.items[name] || (m.items[name] = { q: 0, p: 0 });
      e.q += value.q;
      e.p += value.p;
    }
  }
  return out;
}

// --- Customers -----------------------------------------------------------
//
// One record per customer (the phone number on the delivery address), per
// store, for each month and for all time: how many orders they placed and
// what their revenue orders came to. The admin's Customers page reads the
// biggest spenders from these instead of grouping every order.

/** The record for [phone] in [period] ('YYYY-MM', or 'all'). */
function customerDocId(period, storeId, phone) {
  return period + '__' + (storeId || 'none') + '__' + phone;
}

/** What one order adds to its customer's records; null if it has no phone. */
function customerContribution(order) {
  const c = contribution(order);
  if (!c) return null;
  const address = order.address || {};
  const phone = typeof address.phone === 'string' ? address.phone.trim() : '';
  if (phone === '' || phone.includes('/')) return null;
  return {
    phone,
    storeId: c.storeId,
    month: c.day.slice(0, 7),
    orders: 1,
    spentPaise: c.totals.revenuePaise,
    name: typeof address.name === 'string' ? address.name : '',
    pincode: typeof address.pincode === 'string' ? address.pincode : '',
    at: Number(order.createdAt),
  };
}

function addCustomer(out, c, sign, withLatest) {
  if (!c) return;
  for (const period of [c.month, 'all']) {
    const id = customerDocId(period, c.storeId, c.phone);
    const m =
      out[id] ||
      (out[id] = {
        period,
        storeId: c.storeId,
        phone: c.phone,
        orders: 0,
        spentPaise: 0,
        latest: null,
      });
    m.orders += sign * c.orders;
    m.spentPaise += sign * c.spentPaise;
    if (withLatest && (!m.latest || c.at >= m.latest.lastOrderAt)) {
      m.latest = { name: c.name, pincode: c.pincode, lastOrderAt: c.at };
    }
  }
}

/**
 * What must change in the customer records when an order goes from
 * [before] to [after]. Amounts are to add; `latest` (name, pincode and
 * time of the newest order) is set only for a newly placed order.
 */
function customerChanges(before, after) {
  const out = {};
  addCustomer(out, customerContribution(before), -1, false);
  addCustomer(out, customerContribution(after), 1, !before);
  for (const [id, m] of Object.entries(out)) {
    if (m.orders === 0 && m.spentPaise === 0 && !m.latest) delete out[id];
  }
  return out;
}

/** Every customer record in full, for a list of orders. */
function customerTotalsFor(orders) {
  const out = {};
  for (const order of orders) {
    addCustomer(out, customerContribution(order), 1, true);
  }
  return out;
}

module.exports = {
  dayOf,
  dayDocId,
  contribution,
  changes,
  totalsFor,
  customerDocId,
  customerChanges,
  customerTotalsFor,
};
