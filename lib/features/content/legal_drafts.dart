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

  final text = switch (pageId) {
    LegalPage.privacyId => _privacy,
    LegalPage.deliveryTermsId => _deliveryTerms,
    LegalPage.deliveryPrivacyId => _deliveryPrivacy,
    _ => _terms,
  };
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

mart2door is run by [BUSINESS NAME], [BUSINESS ADDRESS] ("we", "us"). This policy explains what information the mart2door customer app collects, why, and the choices you have. By using the app you agree to this policy. Delivery partners have their own policy in the mart2door Delivery app.

1. Information we collect

Account
- Mobile number, used to log you in with a one-time password (OTP).
- Your name and your pincode.

Delivery addresses
- The receiver's name and phone number, house or flat, landmark and pincode. When you order for someone else, this is that person's name, number and address; please give them only with that person's knowledge.
- A map pin for the address, only if you tap "Use my current location". The app reads your phone's location at that moment and saves the pin with that address. It does not track your location at any other time.

Orders and payments
- The items, amounts, coupon or offer used, delivery charges, payment method, payment status and delivery status.
- For online payments, the payment reference from our payment partner, the method used and, for UPI, the UPI ID the payment came from. We never see or store your card number, UPI PIN or bank password.
- If you pay a cash order by scanning the store's QR code, the delivery partner takes a photo of your "payment successful" screen as proof for the store.
- For outstation orders, the delivery company's name and the tracking number.
- Invoices are made on your phone from your order when you download them.

Things you write
- Product reviews: your stars, your comment and your name. Reviews are shown to other customers on the product page.
- The rating you give a delivery.
- Emails and photos you send us when you ask for help.

Wallet and invites
- Your invite code, the friends who joined with it (their numbers are shown partly hidden) and your m2d wallet balance and history.

From your phone
- A notification token, so we can send order updates and offers.
- Searches that found nothing you could buy, and pincodes we do not serve, so the store can plan stock and delivery areas.
- Your cart, saved addresses and pincode are also stored on your phone so the app opens quickly.

We do not read your contacts, photos, files or messages.

2. Permissions the app asks for

- Location: only when you tap "Use my current location" on an address. You can refuse and type the address instead.
- Notifications: for order updates and offers. You can switch them off in your phone settings; order updates then show only inside the app.

3. How we use your information

- To log you in and keep your account secure.
- To take, pack, deliver and bill your orders, from the store that serves your pincode.
- To take payments, and to make refunds.
- To show your orders, invoices, wallet, coupons, offers and invite rewards.
- To send order updates, and offers from the store.
- To answer your questions and resolve complaints.
- To keep the sales and tax records the law requires.
- To prevent fraud and misuse, such as fake invite rewards or misuse of coupons and offers.

We do not sell your information, and we do not use it for third-party advertising.

4. Who we share it with

- Delivery partners see the receiver's name, phone number, address, map pin and items of the orders assigned to them, and the amount to collect.
- For outstation orders, the delivery company gets the receiver's name, phone number and address.
- Other customers see the name, stars and comment of your product reviews.
- Google Firebase (Google LLC) stores our data, sends login OTPs and delivers notifications. Data may be stored on servers outside India.
- Razorpay, our payment partner, processes online payments and receives your phone number and the order amount for that purpose.
- Authorities, when the law requires it.

5. How long we keep it

We keep your account information for as long as you have an account. Order, payment and invoice records are kept for as long as accounting and tax law requires, even after an account is deleted. Reviews stay on the product page until you ask us to remove them or the store removes them.

6. Deleting your account

You can delete your account at any time in the app: Account > Delete account. You will be asked to confirm with an OTP. Deleting removes your login, your name, saved addresses, wallet balance and invite progress. A wallet balance cannot be recovered.

Records of past orders stay with us as sales records, as explained in section 5. They are no longer linked to a login.

If you cannot use the app, write to [SUPPORT EMAIL] with your registered mobile number and we will delete the account within 30 days.

7. Your choices

You can change your name, addresses and pincode in the app. You can ask us for a copy of your information, ask us to correct it, or ask us to remove a review, by writing to [SUPPORT EMAIL].

8. Security

Data is sent over encrypted connections. Access is limited to the store's staff and the delivery partner for your order. No system is completely secure; tell us at once if you think your account has been misused.

9. Children

The app is meant for people aged 18 and over. We do not knowingly collect information from children.

10. Changes to this policy

We may update this policy. The latest version is always in the app, with the date at the top.

11. Contact and grievances

[GRIEVANCE OFFICER NAME], [BUSINESS NAME]
[BUSINESS ADDRESS]
Email: [SUPPORT EMAIL]
Phone: [SUPPORT PHONE]

We acknowledge complaints within 48 hours and aim to resolve them within one month.
''';

const _terms = r'''
TERMS AND CONDITIONS

Last updated: [DATE]

These terms apply when you use the mart2door app, run by [BUSINESS NAME], [BUSINESS ADDRESS] ("we", "us"). By ticking the box on the login page, creating an account or placing an order you accept them and our Privacy policy.

1. Your account

You log in with your mobile number and an OTP. You must be 18 or older. Keep your phone and OTPs to yourself; you are responsible for orders placed from your account. Give a correct name, phone number and address so we can deliver.

2. Where and how we deliver

- Instant delivery: to the pincodes we serve, by our delivery partners, from the store that serves your pincode.
- Outstation delivery: outside those pincodes, only the products marked for delivery all over India can be ordered. They are sent through a delivery company and take the number of days shown at checkout.
- You may order instant delivery for a person in a pincode we serve, even when you are elsewhere. You must give that person's correct name, phone number and address; our delivery partner will call them.

At checkout the app checks the delivery pincode. An order cannot be placed for a pincode we do not deliver to.

3. Products, prices and stock

Product photos are for illustration; the pack you receive may look different. Prices include all taxes and can change without notice, but the price shown when you place the order is the price you pay. Stock is kept separately for each store, so a product can be available in one area and sold out in another. If an item runs out after you order, we will contact you, and refund that item if you have already paid.

4. Charges

Your bill shows the item total and any delivery fee, handling fee, rain charge or outstation delivery charge before you pay. Delivery is free above the amount shown in the app.

5. Coupons and offers

- Coupons: each coupon has its own conditions, such as a minimum order, an expiry date or one use per customer. One coupon can be used on an order.
- Cart offers: when the items in your cart reach the amount shown, you may pick one product from the offer list at the offer price, one unit per order. The offer product does not count towards that amount, and it is removed if your cart falls below it.
- Offers apply while stocks last. We may change or end any coupon or offer at any time, and we may refuse or cancel orders that misuse them.

6. Orders and payment

An order is placed when you confirm it at checkout. You can pay online (UPI, card or netbanking) through Razorpay, our payment partner, or choose cash on delivery. With cash on delivery you may pay the delivery partner in cash or by scanning the store's QR code; the delivery partner will take a photo of your payment confirmation as proof. Outstation orders must be paid online.

If an online payment stays pending, the order is kept and you can pay again from the order page; the order is not confirmed until the payment succeeds. If a payment fails, the order is cancelled, and money deducted for a failed payment is returned by your bank or the payment partner.

We may cancel an order we cannot fulfil, for example for a wrong address, an unreachable phone number, a pricing error or suspected misuse. You get a full refund of anything you paid.

7. Delivery

Delivery times shown in the app are estimates and can be affected by weather, traffic and demand. Please make sure someone is available at the address and on the phone number given. If we cannot reach the receiver, the order may be cancelled. For outstation orders, the tracking number is shown on the order once it is shipped, and delivery is completed by the delivery company.

8. Cancellations

You can cancel an instant order in the app until the delivery partner has picked it up. You can cancel an outstation order until it has been shipped. After that an order cannot be cancelled. For help, you can also reach us by writing to [SUPPORT EMAIL] or calling [SUPPORT PHONE].

9. Returns and refunds

Check your order when it arrives. If an item is missing, damaged, expired or not what you ordered, tell us within 24 hours with a photo, and we will replace it or refund it. Fresh items such as fruit, vegetables, dairy and bakery cannot be returned for a change of mind.

Refunds for online payments go back to the original payment method within 5 to 7 working days. Any m2d wallet money used on a cancelled order is returned to your wallet.

10. Invoices

You can download a bill for a delivered order from the order page. Please check the details and tell us within 7 days if anything is wrong.

11. m2d wallet

Wallet money comes from invite rewards and refunds of wallet money. It can be used only to pay for orders in this app. It cannot be withdrawn as cash, transferred to another person or exchanged. A wallet balance is lost if you delete your account.

12. Invite and earn

Share your invite code with friends who have never ordered from mart2door. A friend counts once their first order is delivered. You earn ₹25 in your wallet when your 1st, 3rd, 6th, 10th and 15th friend counts, up to ₹125 in total. Rewards are added after we confirm the delivery and may take some time to appear.

Rewards are not given for your own number, for existing customers, for cancelled or refunded orders, or for accounts that were deleted and created again. We may withhold or take back rewards obtained by misuse, and we may change or end the offer at any time.

13. Reviews and ratings

You can review products you have received and rate your delivery. Reviews appear on the product page with your name as soon as you post them. They must be honest, about the product, and free of abusive, unlawful or personal content. We may remove any review.

14. Notifications

We send notifications about your orders, and about offers from the store. You can switch notifications off in your phone settings.

15. Using the app fairly

Do not use the app for anything unlawful, place fake orders, misuse coupons, offers or invites, or try to disrupt the service. We may suspend or close accounts that misuse the app.

16. Deleting your account

You can delete your account from Account > Delete account. Our Privacy policy explains what is removed and what we must keep.

17. Our responsibility

We will take reasonable care in supplying your order. To the extent the law allows, our liability for any order is limited to the amount you paid for it. Nothing in these terms takes away rights you have under consumer protection law.

18. Changes

We may update these terms. The latest version is always in the app, with the date at the top. Orders are governed by the terms in force when they were placed.

19. Law and disputes

These terms are governed by the laws of India. Courts in [CITY] have jurisdiction.

20. Contact and grievances

[GRIEVANCE OFFICER NAME], [BUSINESS NAME]
[BUSINESS ADDRESS]
Email: [SUPPORT EMAIL]
Phone: [SUPPORT PHONE]

We acknowledge complaints within 48 hours and aim to resolve them within one month.
''';

const _deliveryTerms = r'''
DELIVERY PARTNER TERMS

Last updated: [DATE]

These terms apply when you use the mart2door Delivery app, run by [BUSINESS NAME], [BUSINESS ADDRESS] ("we", "us", "the store"). By logging in and delivering orders you accept them and the Delivery partner privacy policy. Your pay and working arrangement are agreed with the store separately; these terms cover how the app is used.

1. Your account

Only a person the store has added as a delivery partner can use the app. You log in with your registered mobile number and an OTP. The account is for you alone: do not share your phone, OTPs or account, and do not let anyone else deliver in your name.

2. Your documents

After your first login you must submit your date of birth, permanent address, driving licence number with a photo, and Aadhaar number with a photo. The details must be your own, true and up to date. You must hold a valid driving licence for the vehicle you use, and tell the store at once if it expires, is suspended or is cancelled.

3. Being available

Switch on "Available for orders" only when you are ready to deliver. Switch it off when you are not. The store sees whether you are available.

4. Accepting and rejecting orders

Accept an order only if you can pick it up and deliver it promptly. If you cannot, reject it straight away with the reason, so the store can give it to someone else. Do not accept an order and then leave it.

5. Pickup and delivery

- Collect the order from the pickup point shown in the app and check the items before you mark it picked up.
- Handle the items with care, keep them clean and deliver them without delay.
- Deliver only to the address and receiver shown on the order.
- If you cannot reach the receiver, call again after a few minutes and then call the store before you leave.
- Mark an order delivered only after it has been handed over.

6. Collecting payment

- Collect exactly the amount the app shows for a cash order, and nothing for an order that is already paid.
- If the customer wants to pay by scanning, show the store's QR code from the app and take a photo of the customer's "payment successful" screen as proof. Never ask a customer to pay to your own number or account.
- Cash you collect belongs to the store. Hand it over as the store instructs; it shows as handed over once the store confirms it. You are responsible for cash you have collected and not yet handed over.

7. Photos

Take the photos the app asks for (delivery proof, payment proof, your documents) clearly and truthfully. Do not photograph customers, their homes or anything else that is not asked for.

8. Customer information

You see a receiver's name, phone number, address and order only to deliver that order. Do not save, share or use it for anything else, and do not contact customers after the delivery is complete.

9. Conduct and safety

Follow traffic law, wear a helmet, and never use the phone while riding. Be polite to customers and store staff. Do not deliver under the influence of alcohol or drugs. Do not ask customers for tips, extra money or ratings. You are responsible for your vehicle, its papers, insurance and fuel unless the store has agreed otherwise.

10. Ratings

Customers can rate your deliveries. The store sees your ratings and may use them when reviewing your work.

11. Phone and notifications

Keep notifications switched on and the phone connected to the internet while you are available, so new orders reach you. The app uses your phone's location to show the route to the customer.

12. Suspension and removal

The store may switch off or remove your account for false documents, missing cash, misuse of customer information, repeated abandoned orders, rude or unsafe behaviour, or any breach of these terms.

13. Deleting your account

You can delete your account from Profile > Delete account, after finishing or rejecting the orders assigned to you and handing over any cash. The Delivery partner privacy policy explains what is removed and what we must keep.

14. Our responsibility

The app is provided as it is; we do not promise it will always be available or free of errors. To the extent the law allows, we are not liable for loss caused by your own breach of these terms or of the law.

15. Changes

We may update these terms. The latest version is always in the app, with the date at the top.

16. Law and disputes

These terms are governed by the laws of India. Courts in [CITY] have jurisdiction.

17. Contact and grievances

[GRIEVANCE OFFICER NAME], [BUSINESS NAME]
[BUSINESS ADDRESS]
Email: [SUPPORT EMAIL]
Phone: [SUPPORT PHONE]

We acknowledge complaints within 48 hours and aim to resolve them within one month.
''';

const _deliveryPrivacy = r'''
DELIVERY PARTNER PRIVACY POLICY

Last updated: [DATE]

The mart2door Delivery app is run by [BUSINESS NAME], [BUSINESS ADDRESS] ("we", "us", "the store"). This policy explains what information the app collects about delivery partners, why, and the choices you have. By using the app you agree to this policy.

1. Information we collect

Account
- Mobile number, used to log you in with a one-time password (OTP).
- Your name and the store you deliver for, as entered by the store.
- Whether you are available for orders.

Documents you submit
- Date of birth and permanent address.
- Driving licence number and a photo of the licence.
- Aadhaar number and a photo of the Aadhaar card.

Your deliveries
- The orders assigned to you and what you did with them: accepted, rejected and the reason you gave, picked up, delivered, and the times.
- The cash you collected and whether it has been handed over to the store.
- The ratings customers gave your deliveries.

Photos you take in the app
- The delivery proof photo for an order.
- The photo of a customer's "payment successful" screen when they pay by QR scan.

From your phone
- Location: while an order's map is open, the app reads your phone's location to show the route to the customer. It is used on your phone and is not saved on our servers.
- A notification token, so we can alert you to new orders.

We do not read your contacts, messages, or the other photos and files on your phone.

2. Permissions the app asks for

- Camera, and photos if you choose a picture from your gallery: for your documents and for proof photos.
- Location: to show the route on the map.
- Notifications: to alert you to new orders.

3. How we use your information

- To log you in and keep your account secure.
- To confirm who you are and that you may drive, before you deliver for the store.
- To assign orders to you and record deliveries, cash and proof.
- To alert you to new orders.
- To review your work, including customer ratings.
- To settle complaints, missing cash or disputes about an order.
- To keep the records the law requires.

We do not sell your information, and we do not use it for advertising.

4. Who we share it with

- The store's staff see your profile, documents, deliveries, cash and ratings.
- Customers see your name and phone number for the order you are bringing them.
- Google Firebase (Google LLC) stores our data and files, sends login OTPs and delivers notifications. Data may be stored on servers outside India.
- Google Maps shows the map and route.
- Authorities, when the law requires it.

Your documents are never shown to customers.

5. How long we keep it

We keep your account information and documents for as long as you deliver for the store. Records of the orders you delivered, including the cash collected and proof photos, are kept for as long as accounting and tax law requires, even after your account is deleted.

6. Deleting your account

You can delete your account in the app: Profile > Delete account. You must first finish or reject the orders assigned to you. Deleting removes your login and your record from the store's list of delivery partners. Orders you delivered keep your name as part of the store's sales records.

To have your submitted documents removed as well, or if you cannot use the app, write to [SUPPORT EMAIL] with your registered mobile number and we will act within 30 days.

7. Your choices

You can ask the store to correct your name or number. You can ask us for a copy of your information, or ask us to correct your documents, by writing to [SUPPORT EMAIL]. You can switch off location or notifications in your phone settings, but the map and new-order alerts will then not work.

8. Security

Data is sent over encrypted connections. Your documents can be opened only by you and the store's staff. No system is completely secure; tell us at once if you think your account has been misused.

9. Changes to this policy

We may update this policy. The latest version is always in the app, with the date at the top.

10. Contact and grievances

[GRIEVANCE OFFICER NAME], [BUSINESS NAME]
[BUSINESS ADDRESS]
Email: [SUPPORT EMAIL]
Phone: [SUPPORT PHONE]

We acknowledge complaints within 48 hours and aim to resolve them within one month.
''';
