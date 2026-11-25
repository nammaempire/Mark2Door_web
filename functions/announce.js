'use strict';

/**
 * Notifications the store sends to every customer from the admin web
 * ("Notify customers"), for example a sudden offer.
 *
 * The admin web adds a document to `announcements`; the server sends it
 * to the `offers` topic, which every customer phone joins when it signs
 * in. Pure helpers live here so they can be tested without Firebase.
 */

const TOPIC = 'offers';
const MAX_TITLE = 50;
const MAX_BODY = 160;

function clean(value, max) {
  if (typeof value !== 'string') return '';
  return value.replace(/\s+/g, ' ').trim().slice(0, max);
}

/**
 * The notification to send for an announcement document, or null when it
 * has no title or no message, or was already handled.
 */
function announcementMessage(doc) {
  if (!doc || (doc.status && doc.status !== 'sending')) return null;
  const title = clean(doc.title, MAX_TITLE);
  const body = clean(doc.body, MAX_BODY);
  if (!title || !body) return null;
  return { title, body };
}

module.exports = { TOPIC, announcementMessage };
