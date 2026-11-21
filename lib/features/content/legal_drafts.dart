import '../../models/storefront.dart';

/// Starting text for the legal pages, offered in the editor when a page
/// has not been written yet. Nothing here reaches customers until the
/// admin presses Save.
///
/// The store's name, address and support email are filled in from
/// Storefront when they are set. Anything still in [SQUARE BRACKETS] must
/// be replaced by the admin before publishing.
String legalDraft(String pageId, StoreSettings? settings, DateTime today) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December', //
  ];
  String filled(String? value, String placeholder) {
    final v = (value ?? '').trim();
    return v.isEmpty ? placeholder : v;
  }

  final text = pageId == LegalPage.privacyId ? _privacy : _terms;
  return text
      .replaceAll(
        '[DATE]',
        '${today.day} ${months[today.month - 1]} ${today.year}',
      )
      .replaceAll(
        '[BUSINESS NAME]',
        filled(settings?.storeName, '[BUSINESS NAME]'),
      )
      .replaceAll(
        '[BUSINESS ADDRESS]',
        filled(settings?.storeAddress, '[BUSINESS ADDRESS]'),
      )
      .replaceAll(
        '[SUPPORT EMAIL]',
        filled(settings?.supportEmail, '[SUPPORT EMAIL]'),
      )
      .trim();
}

/// True while [text] still holds a placeholder such as [CITY].
bool hasPlaceholder(String text) => RegExp(r'\[[A-Z][A-Z ]+\]').hasMatch(text);

const _privacy = r'''
PRIVACY POLICY

Last updated: [DATE]

mart2door is run by [BUSINESS NAME], [BUSINESS ADDRESS] ("we", "us"). This policy explains what information the mart2door app and the mart2door Delivery app collect, why, and the choices you have. By using the apps you agree to this policy.

1. Information we collect

Customers:
- Mobile number, used to log you in with a one-time password (OTP).
- Your name, which you enter when you set your delivery pincode.
- Delivery addresses: name, phone number, house or flat, landmark and pincode.
- Orders: the items, amounts, payment method, payment status and delivery status, and any rating you give the delivery.
- m2d wallet and invite details: your invite code, the friends who joined with it (their numbers are shown partly hidden) and your wallet balance and history.
- Photos or messages you send us by email when you ask for help.

Delivery partners:
- Mobile number, used to log in with an OTP.
- Your name and availability, as entered by the store.
- The orders assigned to you, what you did with them (accepted, rejected with your reason, picked up, delivered), the cash you collected and handed over, and the ratings customers gave your deliveries.

We do not collect your precise GPS location, contacts, photos or files from your phone. Your saved addresses and cart are also stored on your phone so the app opens quickly.

2. How we use your information

- To log you in and keep your account secure.
- To take, prepare, deliver and bill your orders.
- To show your order history, wallet and invite rewards.
- To answer your questions and resolve complaints.
- To keep sales and tax records the law requires.
- To prevent fraud and misuse, such as fake invite rewards.

We do not sell your information, and we do not use it for third-party advertising.

3. Who we share it with

- Delivery partners see the name, phone number, address and items of the orders assigned to them, and whether to collect cash.
- Customers see the name of the delivery partner bringing their order.
- Google Firebase (Google LLC) stores our data and sends login OTPs. Data may be stored on servers outside India.
- Our payment partner processes online payments. We never see or store your card, UPI PIN or bank password.
- Authorities, when the law requires it.

4. How long we keep it

We keep your account information for as long as you have an account. Order and payment records are kept for as long as accounting and tax law requires, even after an account is deleted.

5. Deleting your account

You can delete your account at any time in the app:
- Customer app: Account > Delete account.
- Delivery app: Profile > Delete account.

You will be asked to confirm with an OTP. Deleting removes your login and your profile. For customers it also removes your name, saved addresses, wallet balance and invite progress; a wallet balance cannot be recovered. For delivery partners it removes your record from the store's list of partners; you must first finish or reject the orders assigned to you.

Records of past orders stay with us as sales records, as explained in section 4. They are no longer linked to a login.

If you cannot use the app, write to [SUPPORT EMAIL] with your registered mobile number and we will delete the account within 30 days.

6. Your choices

You can change your name, addresses and pincode in the app. You can ask us for a copy of your information, or ask us to correct it, by writing to [SUPPORT EMAIL].

7. Security

Data is sent over encrypted connections and access is limited to the store's staff and the delivery partner for your order. No system is completely secure; tell us at once if you think your account has been misused.

8. Children

The apps are meant for people aged 18 and over. We do not knowingly collect information from children.

9. Changes to this policy

We may update this policy. The latest version is always in the app, with the date at the top.

10. Contact and grievances

[GRIEVANCE OFFICER NAME], [BUSINESS NAME]
[BUSINESS ADDRESS]
Email: [SUPPORT EMAIL]
Phone: [SUPPORT PHONE]

We acknowledge complaints within 48 hours and aim to resolve them within one month.
''';

const _terms = r'''
TERMS AND CONDITIONS

Last updated: [DATE]

These terms apply when you use the mart2door app, run by [BUSINESS NAME], [BUSINESS ADDRESS] ("we", "us"). By creating an account or placing an order you accept them.

1. Your account

You log in with your mobile number and an OTP. You must be 18 or older. Keep your phone and OTPs to yourself; you are responsible for orders placed from your account. Give a correct name, phone number and address so we can deliver.

2. Where we deliver

We deliver only to the pincodes we serve. If your pincode is outside our area you can browse the store but cannot place an order.

3. Products and prices

Product photos are for illustration; the pack you receive may look different. Prices include all taxes and can change without notice, but the price shown when you place the order is the price you pay. Items are subject to stock. If an item runs out after you order, we will contact you, and refund that item if you have already paid.

4. Charges

Your bill shows the item total and any delivery fee, handling fee and rain charge before you pay. Delivery is free above the amount shown in the app.

5. Orders and payment

An order is placed when you confirm it at checkout. You can pay online or with cash on delivery. Online payments are handled by our payment partner. If an online payment fails or stays pending, the order is not confirmed until the payment succeeds; money deducted for a failed payment is returned by your bank or the payment partner.

We may cancel an order we cannot fulfil, for example for a wrong address, an unreachable phone number, a pricing error or suspected misuse. You get a full refund of anything you paid.

6. Delivery

Delivery times shown in the app are estimates and can be affected by weather, traffic and demand. Please be available at the address and on the phone number given. If we cannot reach you, the order may be cancelled.

7. Cancellations

You can cancel an order until the delivery partner has picked it up, by writing to [SUPPORT EMAIL] or calling [SUPPORT PHONE]. After pickup an order cannot be cancelled.

8. Returns and refunds

Check your order when it arrives. If an item is missing, damaged, expired or not what you ordered, tell us within 24 hours with a photo, and we will replace it or refund it. Fresh items such as fruit, vegetables, dairy and bakery cannot be returned for a change of mind.

Refunds for online payments go back to the original payment method within 5 to 7 working days. Any m2d wallet money used on a cancelled order is returned to your wallet.

9. m2d wallet

Wallet money comes from invite rewards and refunds of wallet money. It can be used only to pay for orders in this app. It cannot be withdrawn as cash, transferred to another person or exchanged. A wallet balance is lost if you delete your account.

10. Invite and earn

Share your invite code with friends who have never ordered from mart2door. A friend counts once their first order is delivered. You earn ₹25 in your wallet when your 1st, 3rd, 6th, 10th and 15th friend counts, up to ₹125 in total. Rewards are added after we confirm the delivery and may take some time to appear.

Rewards are not given for your own number, for existing customers, for cancelled or refunded orders, or for accounts that were deleted and created again. We may withhold or take back rewards obtained by misuse, and we may change or end the offer at any time.

11. Using the app fairly

Do not use the app for anything unlawful, place fake orders, misuse offers, or try to disrupt the service. Ratings you give must be honest. We may suspend or close accounts that misuse the app.

12. Deleting your account

You can delete your account from Account > Delete account. Our Privacy policy explains what is removed and what we must keep.

13. Our responsibility

We will take reasonable care in supplying your order. To the extent the law allows, our liability for any order is limited to the amount you paid for it. Nothing in these terms takes away rights you have under consumer protection law.

14. Changes

We may update these terms. The latest version is always in the app, with the date at the top. Orders are governed by the terms in force when they were placed.

15. Law and disputes

These terms are governed by the laws of India. Courts in [CITY] have jurisdiction.

16. Contact and grievances

[GRIEVANCE OFFICER NAME], [BUSINESS NAME]
[BUSINESS ADDRESS]
Email: [SUPPORT EMAIL]
Phone: [SUPPORT PHONE]

We acknowledge complaints within 48 hours and aim to resolve them within one month.
''';
