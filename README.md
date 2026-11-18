# mart2door — admin web

Admin console for mart2door, built with Flutter web. It reads and writes the
same Firestore collections as the customer app in `../mart2door`.

## Run it

```bash
flutter pub get
flutter run -d chrome
```

With no extra flags it runs in **sample-data mode** (no backend needed):

| What     | Sample-data value                         |
| -------- | ----------------------------------------- |
| Email    | `admin@mart2door.com`                     |
| Password | `admin123`                                |
| Data     | 20 products, 5 pincodes, ~6 months of generated orders |

Sample data lives in the browser tab and resets on reload. It is not
connected to the customer app until both use Firebase.

## Pages

- **Dashboard** — today's revenue, this month's revenue, orders today,
  average order value, daily revenue (7 days), monthly revenue (6 months),
  recent orders, top products.
- **Orders** — filter by status, open an order, move it to the next status
  or cancel it, assign or change the rider on live orders.
- **Products** — search, filter by category, add, edit, delete, in-stock
  switch.
- **Categories** — add, rename, change artwork, delete (blocked while
  products still use the category).
- **Customers** — everyone who has ordered, by total spend, with each
  customer's order history. Derived from orders; customers are identified
  by the phone number on the delivery address.
- **Riders** — delivery partners: add, edit, mark off duty, remove; shows
  each rider's active deliveries.
- **Reports** — sales for today, last 7 days, this month, last month or a
  custom range; export as CSV (opens in Excel) or PDF.
- **Storefront** — delivery fee, free-delivery threshold and delivery-time
  promise, plus the promo banners on the app home page.
- **Service areas** — add, pause or remove serviceable pincodes.

**Revenue rule:** an order counts unless it was cancelled or its online
payment has not been received. Cash-on-delivery orders count from the moment
they are placed. The rule lives in `Order.countsAsRevenue`.

## Project structure

```
lib/
  main.dart, app.dart
  core/       env flags, providers (composition root), router, theme, widgets
  models/     Product, Category, ServiceArea, Order (same fields as the app)
  data/       repository interfaces + sample-data and Firebase implementations
  features/   auth, shell (sidebar), dashboard, products, orders, areas
test/
  revenue_stats_test.dart   revenue maths, money parsing
  admin_flow_test.dart      end-to-end journeys on sample data
```

The models are a copy of the customer app's Firestore shapes. When the
delivery app is added, move them into one shared Dart package so the three
apps cannot drift apart.

## Firestore collections this console writes

| Collection                | Written here                                   | Read by |
| ------------------------- | ---------------------------------------------- | ------- |
| `products/{id}`           | all fields                                     | customer app |
| `categories/{id}`         | `name`, `icon` (key from `kCategoryIcons`)     | customer app |
| `service_areas/{pincode}` | `active`                                       | customer app |
| `banners/{id}`            | `title`, `subtitle`, `emoji`, `theme`, `categoryId`, `active`, `sortOrder` | customer app |
| `settings/store`          | `deliveryFeePaise`, `freeDeliveryThresholdPaise`, `deliveryEtaMinutes` | customer app |
| `riders/{id}`             | `name`, `phone`, `active`                      | delivery app (to come) |
| `orders/{id}`             | `status`, `riderId`, `riderName`, `riderPhone` | customer and delivery apps |

Category artwork keys and banner colour themes are fixed lists that exist
in both apps (`lib/models/storefront.dart` here, `CategoryStyle` and
`bannerColors` in the customer app). Add new ones in both places.

## Connect Firebase

1. Use the same Firebase project as the customer app. Enable
   **Authentication → Email/Password**.
2. Run `flutterfire configure` in this folder (choose **web**). Then in
   `lib/main.dart` import `firebase_options.dart` and pass
   `options: DefaultFirebaseOptions.currentPlatform` to
   `Firebase.initializeApp` (the comment there shows the exact lines).
3. Create the admin user in the Firebase console, then add a Firestore
   document `admins/{that user's uid}` (any content). Only accounts listed
   there can sign in.
4. Run with `flutter run -d chrome --dart-define=USE_FIREBASE=true`.

**Security rules are required before launch.** The `admins` check in the app
is only a friendly message; real protection is rules that allow writes to
`products`, `categories`, `service_areas` and order `status` only when
`exists(/databases/$(database)/documents/admins/$(request.auth.uid))`.

## Deploy to Firebase Hosting

```bash
flutter build web --release --dart-define=USE_FIREBASE=true
firebase login
firebase use --add          # pick your project (first time only)
firebase deploy --only hosting
```

`firebase.json` already points Hosting at `build/web`.

## Not included yet

- Photo upload (products take a photo link for now; upload needs Firebase
  Storage).
- Reordering banners by drag and drop (new banners go to the end).
- Staff accounts with different access levels.
- Reports and the customer list are computed from the latest 2,000 orders.
  Beyond that, move the totals into a Cloud Function.

## Tests

```bash
flutter test
```
# Mark2Door_web
