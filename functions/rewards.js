'use strict';

// Invite rewards. A customer who invites friends earns wallet money when
// their 1st, 3rd, 6th, 10th and 15th friend has a first order delivered.
// The same rules are shown in the customer app (ReferralRules) and were
// previously applied by the admin web; keep the three in step.
//
// Kept free of Firebase so it can be tested on its own.

const MILESTONES = [1, 3, 6, 10, 15];
const REWARD_PAISE = 2500;

/** How many rewards a customer with this many successful invites has earned. */
function milestonesReached(successfulInvites) {
  return MILESTONES.filter((m) => successfulInvites >= m).length;
}

/**
 * What one more successful invite does to the inviter's [wallet] (its
 * current record, or an empty object). Returns the wallet's new figures
 * and how many rewards are [due] now: usually 0 or 1, more only if an
 * earlier one was missed.
 */
function rewardFor(wallet) {
  const w = wallet || {};
  const num = (v) => (Number.isFinite(Number(v)) ? Math.round(Number(v)) : 0);
  const invites = num(w.successfulInvites) + 1;
  const rewarded = num(w.rewardedMilestones);
  const reached = milestonesReached(invites);
  const due = reached > rewarded ? reached - rewarded : 0;
  return {
    invites,
    due,
    balancePaise: num(w.balancePaise) + due * REWARD_PAISE,
    rewardedMilestones: rewarded + due,
    note:
      'Invite reward: ' + invites + ' ' +
      (invites === 1 ? 'friend has' : 'friends have') + ' ordered',
  };
}

/** True when a delivered order still has to be checked for an invite reward. */
function needsRewardCheck(order) {
  return (
    !!order &&
    order.status === 'delivered' &&
    order.referralChecked !== true &&
    typeof order.userId === 'string' &&
    order.userId !== '' &&
    !order.userId.includes('/')
  );
}

module.exports = {
  MILESTONES,
  REWARD_PAISE,
  milestonesReached,
  rewardFor,
  needsRewardCheck,
};
