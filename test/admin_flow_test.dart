import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mart2door_admin/app.dart';
import 'package:mart2door_admin/core/banner_art.dart';
import 'package:mart2door_admin/core/emoji_picker.dart';
import 'package:mart2door_admin/core/providers.dart';
import 'package:mart2door_admin/features/auth/login_screen.dart';
import 'package:mart2door_admin/features/dashboard/dashboard_screen.dart';
import 'package:mart2door_admin/features/products/products_screen.dart';
import 'package:mart2door_admin/data/fake_repositories.dart';
import 'package:mart2door_admin/models/coupon.dart';
import 'package:mart2door_admin/models/order.dart';
import 'package:mart2door_admin/models/product.dart';
import 'package:mart2door_admin/features/content/legal_drafts.dart';
import 'package:mart2door_admin/models/storefront.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end journeys against the sample-data repositories.
Future<void> _pumpApp(WidgetTester tester, {bool signedIn = true}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(
    signedIn ? {'demo_admin_email': 'admin@mart2door.com'} : {},
  );
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const AdminApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sign in with wrong then right password reaches the dashboard', (
    tester,
  ) async {
    await _pumpApp(tester, signedIn: false);
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('email-field')),
      'admin@mart2door.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password-field')),
      'nope',
    );
    await tester.tap(find.byKey(const ValueKey('sign-in-button')));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect email or password.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('password-field')),
      'admin123',
    );
    await tester.tap(find.byKey(const ValueKey('sign-in-button')));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text("Today's revenue"), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
  });

  testWidgets('add a product and see it in the list', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/products')));
    await tester.pumpAndSettle();
    expect(find.byType(ProductsScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-product-button')));
    await tester.pumpAndSettle();

    // Empty form is rejected.
    await tester.tap(find.byKey(const ValueKey('save-product-button')));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('product-name')),
      'Green Grapes',
    );
    await tester.enterText(find.byKey(const ValueKey('product-unit')), '500 g');
    await tester.enterText(find.byKey(const ValueKey('product-price')), '89');
    await tester.enterText(find.byKey(const ValueKey('product-mrp')), '70');
    await tester.tap(find.byKey(const ValueKey('save-product-button')));
    await tester.pumpAndSettle();
    expect(find.text("MRP can't be below the selling price"), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('product-mrp')), '110');
    await tester.tap(find.byKey(const ValueKey('save-product-button')));
    await tester.pumpAndSettle();

    expect(find.text('Green Grapes'), findsOneWidget);
    expect(find.text('₹89'), findsOneWidget);
    expect(find.textContaining('21 of 21 products'), findsOneWidget);
  });

  testWidgets('search filters products and delete removes one', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/products')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('product-search')),
      'tomato',
    );
    await tester.pumpAndSettle();
    expect(find.text('Tomato Local'), findsOneWidget);
    expect(find.text('Onion'), findsNothing);

    // The table scrolls sideways when columns do not fit.
    await tester.ensureVisible(find.byKey(const ValueKey('delete-p02')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-p02')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No products match this search.'), findsOneWidget);
  });

  testWidgets('add and pause a service area', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/areas')));
    await tester.pumpAndSettle();
    expect(find.textContaining('5 of 5 pincodes active'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('pincode-field')), '5600');
    await tester.tap(find.byKey(const ValueKey('add-pincode-button')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid 6-digit pincode'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('pincode-field')),
      '560095',
    );
    await tester.tap(find.byKey(const ValueKey('add-pincode-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('6 of 6 pincodes active'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('area-switch-560095')));
    await tester.pumpAndSettle();
    expect(find.textContaining('5 of 6 pincodes active'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
  });

  testWidgets('orders page lists orders and filters by status', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/orders')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Showing 25 of'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Cancelled'));
    await tester.pumpAndSettle();
    expect(find.text('Delivered'), findsOneWidget); // only the filter chip
  });

  testWidgets('add a category, then it cannot be deleted while in use', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/categories')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-category-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('category-name')),
      'Bakery',
    );
    await tester.tap(find.byKey(const ValueKey('icon-bakery')));
    await tester.tap(find.byKey(const ValueKey('save-category-button')));
    await tester.pumpAndSettle();
    expect(find.text('Bakery'), findsOneWidget);

    // "Fruits & Veg" has products, so deleting it is refused.
    final delete = find.byKey(const ValueKey('delete-category-fruits'));
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining('still use this category'), findsOneWidget);
    expect(find.text('Fruits & Veg'), findsOneWidget);
  });

  testWidgets('delivery settings validate and save', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/storefront')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('setting-eta')), '2');
    await tester.tap(find.byKey(const ValueKey('save-settings-button')));
    await tester.pumpAndSettle();
    expect(find.text('Enter 5 to 240 minutes'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('setting-eta')), '45');
    await tester.enterText(find.byKey(const ValueKey('setting-fee')), '25');
    await tester.tap(find.byKey(const ValueKey('save-settings-button')));
    await tester.pumpAndSettle();
    expect(find.text('Delivery settings saved'), findsOneWidget);
    // The form is rebuilt from the stored values.
    expect(find.widgetWithText(TextFormField, '45'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '25'), findsOneWidget);
  });

  testWidgets('add a banner and hide it', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/storefront')));
    await tester.pumpAndSettle();

    final add = find.byKey(const ValueKey('add-banner-button'));
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('banner-title')),
      'Weekend dairy deals',
    );
    await tester.enterText(
      find.byKey(const ValueKey('banner-subtitle')),
      'Milk, curd and eggs',
    );
    // Emoji comes from the picker, found by searching.
    await tester.tap(find.byKey(const ValueKey('banner-emoji')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('emoji-search')), 'milk');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('emoji-🍌')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('emoji-🥛')));
    await tester.pumpAndSettle();

    for (final key in ['layout-spotlight', 'theme-teal']) {
      final choice = find.byKey(ValueKey(key));
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      await tester.tap(choice);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('save-banner-button')));
    await tester.pumpAndSettle();
    expect(find.text('Banner saved'), findsOneWidget);
    expect(find.text('Showing'), findsNWidgets(4));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AdminApp)),
    );
    final saved = container
        .read(bannersProvider)
        .requireValue
        .firstWhere((b) => b.title == 'Weekend dairy deals');
    expect(saved.emoji, '🥛');
    expect(saved.layout, 'spotlight');
    expect(saved.theme, 'teal');

    final toggle = find.byKey(const ValueKey('banner-switch-b11'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Hidden'), findsOneWidget);
  });

  testWidgets('every banner design draws at preview and phone sizes', (
    tester,
  ) async {
    expect(kBannerLayouts.keys, bannerLayouts);
    for (final size in const [Size(150, 75), Size(210, 105), Size(314, 158)]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: Wrap(
              children: [
                for (final layout in bannerLayouts)
                  SizedBox.fromSize(
                    size: size,
                    child: BannerArt(
                      title: 'Monthly staples\nat mart prices everywhere',
                      subtitle: 'Atta, rice, dal, oil and much more inside',
                      emoji: '🛒',
                      colors: kBannerThemes['teal']!,
                      layout: layout,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  test('emoji picker lists each emoji once and banner round-trips', () {
    final all = [
      for (final g in kEmojiGroups)
        for (final o in g.options) o.emoji,
    ];
    expect(all.toSet().length, all.length);
    expect(all.length, greaterThan(200));

    const banner = PromoBanner(
      id: 'x',
      title: 't',
      subtitle: 's',
      emoji: '🥛',
      theme: 'teal',
      layout: 'offerTag',
      categoryId: 'dairy',
    );
    expect(PromoBanner.fromMap('x', banner.toMap()).layout, 'offerTag');
    // Banners saved before designs existed fall back to the original one.
    expect(
      PromoBanner.fromMap('y', banner.toMap()..remove('layout')).layout,
      'classic',
    );
  });

  testWidgets('pick and clear a product emoji', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/products')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-product-button')));
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('product-emoji'));
    expect(find.descendant(of: field, matching: find.text('None')),
        findsOneWidget);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('emoji-🍌')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: field, matching: find.text('🍌')),
        findsOneWidget);

    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('emoji-none')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: field, matching: find.text('None')),
        findsOneWidget);
  });

  testWidgets('extra charges: switch on handling fee and save', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/storefront')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AdminApp)),
    );
    expect(
      container.read(storeSettingsProvider).requireValue.handlingFeeEnabled,
      isFalse,
    );

    final toggle = find.byKey(const ValueKey('setting-handling-switch'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('save-settings-button'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    // Switched on with no amount is rejected.
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Must be more than 0'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('setting-handling')),
      '5',
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Delivery settings saved'), findsOneWidget);

    final saved = container.read(storeSettingsProvider).requireValue;
    expect(saved.handlingFeeEnabled, isTrue);
    expect(saved.handlingFeePaise, 500);
    expect(saved.rainFeeEnabled, isFalse);
  });

  testWidgets('add up to five photo links to a product', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/products')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-product-button')));
    await tester.pumpAndSettle();
    // Sample data has no upload; links only.
    expect(find.byKey(const ValueKey('upload-image')), findsNothing);

    final addLink = find.byKey(const ValueKey('add-image-link'));
    for (var i = 0; i < Product.maxImages; i++) {
      await tester.ensureVisible(addLink);
      await tester.pumpAndSettle();
      await tester.tap(addLink);
      await tester.pumpAndSettle();
    }
    expect(find.text('Photos (5 of 5)'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(addLink).onPressed, isNull);

    final remove = find.byKey(const ValueKey('remove-image-4'));
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('Photos (4 of 5)'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('product-image-0')),
      'not a link',
    );
    await tester.tap(find.byKey(const ValueKey('save-product-button')));
    await tester.pumpAndSettle();
    expect(find.text('Must be an https:// link'), findsOneWidget);
  });

  test('product photos, extra charges and refunds round-trip', () async {
    const product = Product(
      id: 'p',
      name: 'Mango',
      categoryId: 'fruits',
      unit: '1 kg',
      pricePaise: 9900,
      mrpPaise: 12000,
      imageUrls: ['https://a/1.jpg', 'https://a/2.jpg'],
    );
    final map = product.toMap();
    expect(map['imageUrl'], 'https://a/1.jpg');
    expect(Product.fromMap('p', map).imageUrls, product.imageUrls);
    // Saved before several photos existed.
    expect(
      Product.fromMap('p', {'imageUrl': 'https://a/old.jpg'}).imageUrls,
      ['https://a/old.jpg'],
    );
    expect(
      Product.fromMap('p', {
        'imageUrls': [for (var i = 0; i < 9; i++) 'https://a/$i.jpg'],
      }).imageUrls,
      hasLength(Product.maxImages),
    );

    expect(StoreSettings.fromMap(const {}).handlingFeeEnabled, isFalse);
    const settings = StoreSettings(
      deliveryFeePaise: 3000,
      freeDeliveryThresholdPaise: 49900,
      deliveryEtaMinutes: 30,
      rainFeeEnabled: true,
      rainFeePaise: 1500,
    );
    final read = StoreSettings.fromMap(settings.toMap());
    expect(read.rainFeeEnabled, isTrue);
    expect(read.rainFeePaise, 1500);

    final repo = FakeOrdersAdminRepository();
    final paid = (await repo.watchOrders().first).firstWhere(
      (o) =>
          o.paymentMethod == PaymentMethod.online &&
          o.paymentStatus == PaymentStatus.paid,
    );
    expect(paid.needsRefund, isFalse);
    await repo.updateStatus(paid.id, OrderStatus.cancelled);
    var now = (await repo.watchOrders().first).firstWhere((o) => o.id == paid.id);
    expect(now.needsRefund, isTrue);
    expect(now.paymentLabel, 'Refund due');
    await repo.markRefunded(paid.id);
    now = (await repo.watchOrders().first).firstWhere((o) => o.id == paid.id);
    expect(now.needsRefund, isFalse);
    expect(now.paymentLabel, 'Refunded');
    expect(now.countsAsRevenue, isFalse);
  });

  testWidgets('help and legal: write and delete terms, add a question', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/content')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AdminApp)),
    );
    expect(
      find.text('Not published. Open the pencil for a ready-made draft.'),
      findsNWidgets(2),
    );

    await tester.tap(find.byKey(const ValueKey('edit-page-terms')));
    await tester.pumpAndSettle();
    // The editor opens with the draft, which still has blanks to fill, so
    // it cannot be published as it stands.
    final draft = tester
        .widget<TextFormField>(find.byKey(const ValueKey('page-body')))
        .controller!
        .text;
    expect(draft, startsWith('TERMS AND CONDITIONS'));
    expect(draft, contains('[CITY]'));
    expect(find.byKey(const ValueKey('placeholder-warning')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save-page-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Replace the details'), findsOneWidget);
    expect(container.read(legalPagesProvider).requireValue, isEmpty);

    // An empty page cannot be saved either; deleting is how one is removed.
    await tester.enterText(find.byKey(const ValueKey('page-body')), '');
    await tester.tap(find.byKey(const ValueKey('save-page-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Write the page'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('page-body')),
      'Orders are delivered within the service area only.',
    );
    await tester.tap(find.byKey(const ValueKey('save-page-button')));
    await tester.pumpAndSettle();
    expect(find.text('Terms and conditions saved'), findsOneWidget);
    expect(
      container.read(legalPagesProvider).requireValue[LegalPage.termsId]!.body,
      'Orders are delivered within the service area only.',
    );
    expect(find.text('Live'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delete-page-terms')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(container.read(legalPagesProvider).requireValue, isEmpty);

    final addFaq = find.byKey(const ValueKey('add-faq-button'));
    await tester.ensureVisible(addFaq);
    await tester.pumpAndSettle();
    await tester.tap(addFaq);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('faq-question')),
      'Can I change my address?',
    );
    await tester.enterText(
      find.byKey(const ValueKey('faq-answer')),
      'Yes, tap Change at checkout.',
    );
    await tester.tap(find.byKey(const ValueKey('save-faq-button')));
    await tester.pumpAndSettle();
    final faqs = container.read(faqsProvider).requireValue;
    expect(faqs, hasLength(3));
    expect(faqs.last.question, 'Can I change my address?');
    expect(faqs.last.sortOrder, 2);

    final delete = find.byKey(const ValueKey('delete-faq-f1'));
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(container.read(faqsProvider).requireValue, hasLength(2));
  });

  testWidgets('store name, address and support email are saved', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/storefront')));
    await tester.pumpAndSettle();
    final email = find.byKey(const ValueKey('setting-support-email'));
    await tester.ensureVisible(email);
    await tester.pumpAndSettle();
    await tester.enterText(email, 'not-an-email');
    final save = find.byKey(const ValueKey('save-settings-button'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget);

    await tester.enterText(email, 'help@mart2door.com');
    await tester.enterText(
      find.byKey(const ValueKey('setting-store-name')),
      'mart2door Palayamkottai',
    );
    await tester.enterText(
      find.byKey(const ValueKey('setting-store-address')),
      '12 High Ground Road, Tirunelveli 627004',
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AdminApp)),
    );
    final saved = container.read(storeSettingsProvider).requireValue;
    expect(saved.supportEmail, 'help@mart2door.com');
    expect(saved.storeName, 'mart2door Palayamkottai');
    expect(
      StoreSettings.fromMap(saved.toMap()).storeAddress,
      '12 High Ground Road, Tirunelveli 627004',
    );
  });

  test('orders know when the console has wallet work to do', () {
    Order order(String status, {int wallet = 0, Map<String, dynamic>? extra}) =>
        Order.fromMap('o1', {
          'userId': 'u1',
          'status': status,
          'totalPaise': 7200,
          'walletAppliedPaise': wallet,
          'paymentMethod': 'cod',
          ...?extra,
        });
    expect(order('placed').needsSettlement, isFalse);
    expect(order('delivered').needsSettlement, isTrue);
    expect(
      order('delivered', extra: {'referralChecked': true}).needsSettlement,
      isFalse,
    );
    expect(order('cancelled').needsSettlement, isFalse);
    expect(order('cancelled', wallet: 2500).needsSettlement, isTrue);
    expect(
      order('cancelled', wallet: 2500, extra: {'walletRefunded': true})
          .needsSettlement,
      isFalse,
    );
    expect(order('placed', wallet: 2500).payablePaise, 4700);
    expect(ReferralRules.milestonesReached(6), 3);
  });

  testWidgets('add a rider', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/riders')));
    await tester.pumpAndSettle();
    expect(find.text('Suresh Kumar'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-rider-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('rider-name')), 'Kiran P');
    await tester.enterText(find.byKey(const ValueKey('rider-phone')), '12345');
    await tester.tap(find.byKey(const ValueKey('save-rider-button')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('rider-phone')),
      '9876501234',
    );
    await tester.tap(find.byKey(const ValueKey('save-rider-button')));
    await tester.pumpAndSettle();
    expect(find.text('Kiran P'), findsOneWidget);
  });

  testWidgets('customers page lists customers and opens their history', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/customers')));
    await tester.pumpAndSettle();
    expect(find.textContaining('6 of 6 customers'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('customer-search')),
      'meera',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1 of 6 customers'), findsOneWidget);

    await tester.tap(find.text('Meera Iyer'));
    await tester.pumpAndSettle();
    expect(find.textContaining(' orders · '), findsOneWidget);
  });

  testWidgets('reports page switches period and offers both exports', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/reports')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('export-csv-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('export-pdf-button')), findsOneWidget);

    String range() =>
        tester.widget<Text>(find.byKey(const ValueKey('report-range'))).data!;
    final month = range();
    await tester.tap(find.byKey(const ValueKey('preset-last7')));
    await tester.pumpAndSettle();
    expect(range(), isNot(month));
    await tester.tap(find.byKey(const ValueKey('preset-today')));
    await tester.pumpAndSettle();
    expect(range(), isNot(contains(' to ')));
  });

  testWidgets('assign a rider to a live order', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/orders')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Placed'));
    await tester.pumpAndSettle();

    final assign = find.text('Assign').first;
    await tester.ensureVisible(assign);
    await tester.pumpAndSettle();
    await tester.tap(assign);
    await tester.pumpAndSettle();
    // Off-duty riders are not offered.
    expect(find.text('Abdul Rahman'), findsNothing);
    await tester.tap(find.text('Suresh Kumar').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('assigned to Suresh Kumar'), findsOneWidget);
  });

  testWidgets('orders show a rider\'s rejection reason and slow acceptance', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/orders')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Placed'));
    await tester.pumpAndSettle();

    // Handed back by a rider and not yet given to anyone else.
    expect(find.text('Rejected: Bike has a puncture'), findsOneWidget);
    // Assigned seven minutes ago and still not accepted.
    expect(find.text('Not accepted · 7 min'), findsOneWidget);

    // The full reason is on the order's detail.
    // Opened by clicking the row: here, the order number on the same line.
    final rowY =
        tester.getCenter(find.text('Rejected: Bike has a puncture')).dy;
    final orderNumber = find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').startsWith('#'),
    );
    final inRow = orderNumber.evaluate().firstWhere((e) {
      final box = e.renderObject! as RenderBox;
      final y = box.localToGlobal(box.size.center(Offset.zero)).dy;
      return (y - rowY).abs() < 16;
    });
    await tester.tap(find.byWidget(inRow.widget));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reject-reason')), findsOneWidget);
    expect(find.textContaining('Rejected by Abdul Rahman'), findsOneWidget);
  });

  test('awaiting rider only when placed, assigned and past five minutes', () {
    final now = DateTime(2026, 11, 20, 12);
    Order order(String status, int? assignedMinutesAgo) => Order.fromMap('o', {
      'status': status,
      'riderId': assignedMinutesAgo == null ? null : 'r1',
      'assignedAt': assignedMinutesAgo == null
          ? null
          : now
                .subtract(Duration(minutes: assignedMinutesAgo))
                .millisecondsSinceEpoch,
      'rejectReason': 'Too far away',
    });
    expect(order('placed', 4).isAwaitingRiderAt(now), isFalse);
    expect(order('placed', 5).isAwaitingRiderAt(now), isTrue);
    expect(order('accepted', 9).isAwaitingRiderAt(now), isFalse);
    expect(order('placed', null).isAwaitingRiderAt(now), isFalse);
    // The reason shows as open only until another rider is assigned.
    expect(order('placed', null).hasOpenRejection, isTrue);
    expect(order('placed', 1).hasOpenRejection, isFalse);
  });

  test('legal drafts use the store details and flag what is left', () {
    final today = DateTime(2026, 11, 20);
    final bare = legalDraft(LegalPage.privacyId, null, today);
    expect(bare, startsWith('PRIVACY POLICY'));
    expect(bare, contains('Last updated: 20 November 2026'));
    expect(bare, contains('[BUSINESS NAME]'));
    expect(hasPlaceholder(bare), isTrue);

    const settings = StoreSettings(
      deliveryFeePaise: 0,
      freeDeliveryThresholdPaise: 0,
      deliveryEtaMinutes: 20,
      storeName: 'Fresh Mart',
      storeAddress: '80 Feet Road, Bengaluru',
      supportEmail: 'help@freshmart.in',
    );
    final terms = legalDraft(LegalPage.termsId, settings, today);
    expect(terms, contains('run by Fresh Mart, 80 Feet Road, Bengaluru'));
    expect(terms, contains('writing to help@freshmart.in'));
    expect(terms, isNot(contains('[BUSINESS NAME]')));
    // City, phone and grievance officer are still for the admin to fill.
    expect(hasPlaceholder(terms), isTrue);
    expect(hasPlaceholder('Courts in Bengaluru have jurisdiction.'), isFalse);
  });

  testWidgets('riders show their rating; cash received clears what they owe', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/riders')));
    await tester.pumpAndSettle();

    String text(String key) =>
        tester.widget<Text>(find.byKey(ValueKey(key))).data!;
    expect(text('rider-rating-r1'), matches(RegExp(r'^\d\.\d · \d+ ratings$')));
    // The off-duty sample rider has delivered nothing.
    expect(text('rider-rating-r3'), 'No ratings yet');
    expect(text('rider-cash-r3'), 'Cash to hand over: ₹0');
    expect(find.byKey(const ValueKey('cash-received-r3')), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AdminApp)),
    );
    final owed = container
        .read(ordersProvider)
        .requireValue
        .where((o) => o.riderId == 'r1' && o.cashWithRider)
        .fold(0, (sum, o) => sum + o.payablePaise);
    expect(owed, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey('cash-received-r1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash received').last);
    await tester.pumpAndSettle();
    expect(text('rider-cash-r1'), 'Cash to hand over: ₹0');
    expect(find.byKey(const ValueKey('cash-received-r1')), findsNothing);
    expect(
      container
          .read(ordersProvider)
          .requireValue
          .where((o) => o.riderId == 'r1' && o.cashWithRider),
      isEmpty,
    );
  });

  testWidgets('add a coupon, switch it off and delete it', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/coupons')));
    await tester.pumpAndSettle();
    expect(find.text('SAVE10'), findsOneWidget);
    expect(find.text('10% off, up to ₹100'), findsOneWidget);
    expect(find.textContaining('Once per customer'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-coupon-button')));
    await tester.pumpAndSettle();

    // A code that exists, and a percent above 100, are both refused.
    await tester.enterText(find.byKey(const ValueKey('coupon-code')), 'save10');
    await tester.enterText(find.byKey(const ValueKey('coupon-value')), '150');
    await tester.tap(find.byKey(const ValueKey('save-coupon-button')));
    await tester.pumpAndSettle();
    expect(find.text('This code already exists'), findsOneWidget);
    expect(find.text('Enter 1 to 100'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('coupon-code')), 'diwali20');
    await tester.enterText(find.byKey(const ValueKey('coupon-value')), '20');
    await tester.enterText(
      find.byKey(const ValueKey('coupon-max-discount')),
      '75',
    );
    await tester.enterText(
      find.byKey(const ValueKey('coupon-min-order')),
      '299',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('coupon-once')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('coupon-once')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-coupon-button')));
    await tester.pumpAndSettle();

    // Saved in upper case, with its terms spelled out.
    expect(find.text('DIWALI20'), findsOneWidget);
    expect(find.text('20% off, up to ₹75'), findsOneWidget);
    expect(
      find.text(
        'Item total of ₹299 or more · Once per customer · No expiry',
      ),
      findsOneWidget,
    );
    final status = find.byKey(const ValueKey('coupon-status-DIWALI20'));
    expect(
      find.descendant(of: status, matching: find.text('Active')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('coupon-active-DIWALI20')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: status, matching: find.text('Switched off')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('delete-coupon-DIWALI20')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('DIWALI20'), findsNothing);
  });

  test('coupons are saved the way the customer app reads them', () {
    final coupon = Coupon(
      code: 'FLAT50',
      type: CouponType.flat,
      value: 5000,
      minOrderPaise: 19900,
      expiresAt: DateTime(2026, 12, 31, 23, 59, 59),
      oncePerCustomer: true,
    );
    final map = coupon.toMap();
    expect(map['type'], 'flat');
    expect(map['value'], 5000);
    expect(map['oncePerCustomer'], isTrue);
    final back = Coupon.fromMap('FLAT50', map);
    expect(back.offer, '₹50 off');
    expect(back.expiresAt, coupon.expiresAt);
    expect(back.isExpiredAt(DateTime(2027)), isTrue);
    expect(back.isExpiredAt(DateTime(2026, 12, 31, 12)), isFalse);
    expect(Coupon.isValidCode('SAVE10'), isTrue);
    expect(Coupon.isValidCode('SAVE 10'), isFalse);
    expect(Coupon.isValidCode('AB'), isFalse);
  });

  testWidgets('a product keeps its subtitle and stock quantity', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-/products')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-product-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('product-name')), 'Apple');
    await tester.enterText(
      find.byKey(const ValueKey('product-subtitle')),
      'Fresh from Ooty',
    );
    await tester.enterText(find.byKey(const ValueKey('product-unit')), '4 pcs');
    await tester.enterText(find.byKey(const ValueKey('product-price')), '129');
    await tester.enterText(find.byKey(const ValueKey('product-mrp')), '160');
    await tester.ensureVisible(find.byKey(const ValueKey('product-stock')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('product-stock')), '8');
    await tester.tap(find.byKey(const ValueKey('save-product-button')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AdminApp)),
    );
    final apple = (await container
            .read(catalogRepositoryProvider)
            .watchProducts()
            .first)
        .firstWhere((p) => p.name == 'Apple');
    expect(apple.subtitle, 'Fresh from Ooty');
    expect(apple.stockQty, 8);
    expect(find.byKey(ValueKey('stock-left-${apple.id}')), findsOneWidget);
  });

  test('stock is saved for the customer app and counts as sold out at 0', () {
    const apple = Product(
      id: 'a',
      name: 'Apple',
      categoryId: 'fruits',
      unit: '4 pcs',
      pricePaise: 12900,
      mrpPaise: 16000,
      subtitle: 'Fresh from Ooty',
      stockQty: 8,
    );
    final map = apple.toMap();
    expect(map['stockQty'], 8);
    expect(map['subtitle'], 'Fresh from Ooty');
    expect(apple.canBeOrdered, isTrue);
    expect(Product.fromMap('a', {...map, 'stockQty': 0}).canBeOrdered, isFalse);
    // Not counted: saved as null, and there is no limit.
    final uncounted = Product.fromMap('a', {...map, 'stockQty': null});
    expect(uncounted.stockQty, isNull);
    expect(uncounted.canBeOrdered, isTrue);
  });

  test('orders carry the coupon and who cancelled them', () {
    final order = Order.fromMap('o1', const {
      'totalPaise': 6780,
      'subtotalPaise': 4200,
      'deliveryFeePaise': 3000,
      'couponCode': 'SAVE10',
      'couponDiscountPaise': 420,
      'status': 'cancelled',
      'cancelledBy': 'customer',
    });
    expect(order.couponCode, 'SAVE10');
    expect(order.couponDiscountPaise, 420);
    expect(order.cancelledBy, 'customer');
  });

  testWidgets('sign out returns to the login page', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('sign-out-button')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
