import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mart2door_admin/app.dart';
import 'package:mart2door_admin/core/providers.dart';
import 'package:mart2door_admin/features/auth/login_screen.dart';
import 'package:mart2door_admin/features/dashboard/dashboard_screen.dart';
import 'package:mart2door_admin/features/products/products_screen.dart';
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
    await tester.ensureVisible(find.byKey(const ValueKey('theme-blue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('theme-blue')));
    await tester.tap(find.byKey(const ValueKey('save-banner-button')));
    await tester.pumpAndSettle();
    expect(find.text('Banner saved'), findsOneWidget);
    expect(find.text('Showing'), findsNWidgets(4));

    final toggle = find.byKey(const ValueKey('banner-switch-b11'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Hidden'), findsOneWidget);
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

  testWidgets('sign out returns to the login page', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('sign-out-button')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
