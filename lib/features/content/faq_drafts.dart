import '../../models/storefront.dart';

/// Ready-written questions and answers for each app, added from the
/// Help and legal page with "Add suggested questions". They describe how
/// the apps work today; the admin can edit or delete any of them.
List<({String question, String answer})> faqDrafts(String app) =>
    app == Faq.delivery ? _delivery : _customer;

const _customer = <({String question, String answer})>[
  (
    question: 'Where do you deliver?',
    answer: 'Enter your pincode when you open the app. If we deliver there, '
        'you see the full store with instant delivery. If we do not, the '
        'Outstation tab shows the products we send all over India.',
  ),
  (
    question: 'How long does delivery take?',
    answer: 'Instant orders arrive in about the time shown at the top of '
        'the home page. Outstation orders take the number of days shown at '
        'checkout.',
  ),
  (
    question: 'How do I pay?',
    answer: 'Pay online with UPI, card or netbanking, or choose cash on '
        'delivery. Outstation orders are paid online only. With cash on '
        'delivery you can also pay the delivery partner by scanning the '
        'store\'s QR code.',
  ),
  (
    question: 'My payment is pending. What should I do?',
    answer: 'Open the order under Orders and tap "Pay online". Your order '
        'is kept while the payment is pending.',
  ),
  (
    question: 'My payment failed but money left my account.',
    answer: 'A failed payment is returned by your bank to the same account '
        'or card. If it does not come back in a few working days, write to '
        'us from this page with your order number.',
  ),
  (
    question: 'How do I cancel an order?',
    answer: 'Open the order under Orders and tap Cancel. You can cancel '
        'until the delivery partner picks the order up. Outstation orders '
        'can be cancelled until they are shipped.',
  ),
  (
    question: 'When will I get my refund?',
    answer: 'When a paid order is cancelled, the amount goes back to the '
        'way you paid. Wallet money used on the order returns to your m2d '
        'wallet.',
  ),
  (
    question: 'How do I use a coupon?',
    answer: 'At checkout, open the coupon list and tap Apply on a coupon, '
        'or type the code. Coupons that cannot be used on your cart are '
        'greyed out with the reason.',
  ),
  (
    question: 'What is the offer in my cart?',
    answer: 'When the items in your cart reach the amount shown, the offer '
        'list unlocks and you can pick one product at the offer price. If '
        'the cart drops below the amount, the offer product is removed.',
  ),
  (
    question: 'What is the m2d wallet?',
    answer: 'Wallet money comes from invite rewards and refunds. Tick "Use '
        'm2d wallet" at checkout to pay with it.',
  ),
  (
    question: 'How do I track my order?',
    answer: 'The order card at the bottom of the home page shows where your '
        'order is. Open it for the status and the delivery partner\'s '
        'details. Outstation orders show the tracking number once shipped.',
  ),
  (
    question: 'Can I order for someone in another pincode?',
    answer: 'Yes. Choose a pincode we deliver to, then enter the receiver\'s '
        'name, phone number and address at checkout. The delivery partner '
        'calls the receiver.',
  ),
  (
    question: 'How do I change my delivery address or pincode?',
    answer: 'At checkout, tap Change on the address to pick or add another '
        'one, or type a new pincode in the Delivery pincode box. Paying is '
        'switched off for a pincode we do not deliver to.',
  ),
  (
    question: 'An item is out of stock. When will it be back?',
    answer: 'Stock changes through the day. Sold-out items stay visible and '
        'can be ordered again as soon as the store has them.',
  ),
  (
    question: 'How do I get a bill for my order?',
    answer: 'Open a delivered order under Orders and tap Download invoice.',
  ),
  (
    question: 'How do I review a product?',
    answer: 'Open a delivered order and tap Review next to the item. Your '
        'stars and comment show on the product page.',
  ),
  (
    question: 'How do I delete my account?',
    answer: 'Go to Account and choose Delete account. You confirm with an '
        'OTP, and your details are removed from this phone.',
  ),
];

const _delivery = <({String question, String answer})>[
  (
    question: 'How do I start getting orders?',
    answer: 'The store adds your phone number as a delivery partner. Log in '
        'with that number, submit your documents, and switch on "Available '
        'for orders" on the Profile page.',
  ),
  (
    question: 'Which documents do I need to submit?',
    answer: 'Your date of birth, permanent address, driving licence number '
        'with a photo, and Aadhaar number with a photo. You submit them '
        'once, after your first login.',
  ),
  (
    question: 'How do I go offline?',
    answer: 'Switch off "Available for orders" on the Profile page. The '
        'store then sees you as off duty.',
  ),
  (
    question: 'How do I accept or reject an order?',
    answer: 'New orders appear on the home page. Tap Accept to take one. '
        'If you cannot take it, tap Reject so the store can give it to '
        'someone else.',
  ),
  (
    question: 'Where do I pick up the order?',
    answer: 'The pickup point is the store address shown on the order and '
        'on your Profile page. Mark the order as picked up once you have '
        'all the items.',
  ),
  (
    question: 'How do I find the customer\'s address?',
    answer: 'After pickup, tap Navigate on the order to open the map. Tap '
        'Call to speak to the customer or the receiver.',
  ),
  (
    question: 'The customer is not answering. What should I do?',
    answer: 'Call the number on the order again after a few minutes. If you '
        'still cannot reach them, call the store before you leave.',
  ),
  (
    question: 'How do I collect payment for a cash order?',
    answer: 'The order shows the amount to collect. Take the cash, or if '
        'the customer wants to scan, tap "Customer wants to pay by QR '
        'scan", show the store QR and take a photo of their payment '
        'screen as proof.',
  ),
  (
    question: 'Do I collect money for an order paid online?',
    answer: 'No. An order that is already paid shows nothing to collect.',
  ),
  (
    question: 'How do I hand over the cash I collected?',
    answer: 'Give the cash to the store. The admin confirms it, and it then '
        'shows as handed over.',
  ),
  (
    question: 'How do I mark an order as delivered?',
    answer: 'After handing over the order and collecting any payment, tap '
        'Confirm delivered.',
  ),
  (
    question: 'Where can I see my past deliveries?',
    answer: 'Open the History tab for the orders you have delivered.',
  ),
  (
    question: 'I am not getting order alerts.',
    answer: 'Check that "Available for orders" is on, the phone has '
        'internet, and notifications are allowed for the app in your '
        'phone settings.',
  ),
  (
    question: 'How do I delete my account?',
    answer: 'On the Profile page, tap Delete account. You are removed from '
        'the store\'s delivery partner list.',
  ),
];
