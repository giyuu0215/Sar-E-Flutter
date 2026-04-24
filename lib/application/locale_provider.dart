import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bilingual "Taglish" localization — translates key UI labels.
/// Tabs, page headers, and important labels are in Filipino;
/// technical/intuitive labels stay in English.
enum AppLocale { en, fil }

class LocaleNotifier extends StateNotifier<AppLocale> {
  LocaleNotifier() : super(AppLocale.fil) {
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString('app_locale');
    if (saved == 'en') state = AppLocale.en;
  }

  Future<void> setLocale(AppLocale locale) async {
    state = locale;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', locale == AppLocale.en ? 'en' : 'fil');
  }
}

final StateNotifierProvider<LocaleNotifier, AppLocale> localeProvider =
    StateNotifierProvider<LocaleNotifier, AppLocale>((_) => LocaleNotifier());

/// Taglish string table. Keys should match UI elements.
/// Filipino is the default — English is provided as fallback.
const Map<AppLocale, Map<String, String>> _strings =
    <AppLocale, Map<String, String>>{
  AppLocale.fil: <String, String>{
    // Bottom nav
    'tab_pos': 'POS',
    'tab_listahan': 'Listahan',
    'tab_inventory': 'Imbentaryo',
    'tab_analytics': 'Analytics',

    // App bar & headings
    'profile': 'Profile',
    'settings': 'Settings',
    'notifications': 'Mga Abiso',

    // POS / Scanner
    'scan_barcode': 'I-scan ang Barcode',
    'search_product': 'Hanapin ang produkto...',
    'cart_empty': 'Walang laman ang cart',
    'checkout': 'Checkout',
    'add_to_cart': 'Idagdag sa Cart',
    'out_of_stock': 'Ubos na ang stock',
    'payment': 'Bayaran',
    'cash': 'Cash',
    'total': 'Kabuuan',
    'change': 'Sukli',

    // Inventory
    'inventory': 'Imbentaryo',
    'add_product': 'Magdagdag ng Produkto',
    'add_stock': 'Dagdagan ng Stock',
    'edit': 'I-edit',
    'delete': 'Tanggalin',
    'product_name': 'Pangalan ng Produkto',
    'price': 'Presyo',
    'cost': 'Halaga',
    'stock': 'Stock',
    'category': 'Kategorya',
    'all_items': 'Lahat',
    'low_stock': 'Mababang Stock',

    // Listahan
    'new_credit': 'Bagong Utang',
    'customer': 'Customer',
    'amount': 'Halaga',
    'due_date': 'Deadline',
    'repay': 'Bayad',
    'settled': 'Paid',
    'overdue': 'Overdue',
    'active': 'Active',
    'outstanding': 'Natitirang Utang',

    // Analytics
    'revenue': 'Kita',
    'gross_profit': 'Gross Profit',
    'profit_margin': 'Margin',
    'transactions': 'Transaksyon',
    'top_products': 'Mga Top na Produkto',
    'recent_transactions': 'Mga Kamakailang Transaksyon',
    'revenue_vs_cogs': 'Kita vs COGS',
    'view_all': 'Tingnan Lahat',

    // Settings
    'language': 'Wika',
    'notification_settings': 'Mga Setting ng Abiso',
    'low_stock_alerts': 'Alerto sa Mababang Stock',
    'overdue_alerts': 'Alerto sa Overdue',
    'dark_mode': 'Dark Mode',

    // Profile
    'change_pin': 'Palitan ang PIN',
    'add_cashier': 'Magdagdag ng Cashier',
    'logout': 'Mag-logout',
    'sign_out': 'Mag-sign Out',
    'store_name': 'Pangalan ng Tindahan',
    'payment_qr': 'Payment QR Codes',
    'sync_now': 'Mag-sync Ngayon',

    // General
    'cancel': 'Cancel',
    'save': 'Save',
    'confirm': 'Confirm',
    'search': 'Hanapin',
    'no_data': 'Walang data',
    'loading': 'Loading...',
    'error': 'May error',
  },
  AppLocale.en: <String, String>{
    'tab_pos': 'POS',
    'tab_listahan': 'Credits',
    'tab_inventory': 'Inventory',
    'tab_analytics': 'Analytics',
    'profile': 'Profile',
    'settings': 'Settings',
    'notifications': 'Notifications',
    'scan_barcode': 'Scan Barcode',
    'search_product': 'Search product...',
    'cart_empty': 'Cart is empty',
    'checkout': 'Checkout',
    'add_to_cart': 'Add to Cart',
    'out_of_stock': 'Out of stock',
    'payment': 'Payment',
    'cash': 'Cash',
    'total': 'Total',
    'change': 'Change',
    'inventory': 'Inventory',
    'add_product': 'Add Product',
    'add_stock': 'Add Stock',
    'edit': 'Edit',
    'delete': 'Delete',
    'product_name': 'Product Name',
    'price': 'Price',
    'cost': 'Cost',
    'stock': 'Stock',
    'category': 'Category',
    'all_items': 'All',
    'low_stock': 'Low Stock',
    'new_credit': 'New Credit',
    'customer': 'Customer',
    'amount': 'Amount',
    'due_date': 'Due Date',
    'repay': 'Repay',
    'settled': 'Settled',
    'overdue': 'Overdue',
    'active': 'Active',
    'outstanding': 'Outstanding',
    'revenue': 'Revenue',
    'gross_profit': 'Gross Profit',
    'profit_margin': 'Margin',
    'transactions': 'Transactions',
    'top_products': 'Top Products',
    'recent_transactions': 'Recent Transactions',
    'revenue_vs_cogs': 'Revenue vs COGS',
    'view_all': 'View All',
    'language': 'Language',
    'notification_settings': 'Notification Settings',
    'low_stock_alerts': 'Low Stock Alerts',
    'overdue_alerts': 'Overdue Alerts',
    'dark_mode': 'Dark Mode',
    'change_pin': 'Change PIN',
    'add_cashier': 'Add Cashier',
    'logout': 'Logout',
    'sign_out': 'Sign Out',
    'store_name': 'Store Name',
    'payment_qr': 'Payment QR Codes',
    'sync_now': 'Sync Now',
    'cancel': 'Cancel',
    'save': 'Save',
    'confirm': 'Confirm',
    'search': 'Search',
    'no_data': 'No data',
    'loading': 'Loading...',
    'error': 'Error',
  },
};

/// Convenience function to get localized string
String t(AppLocale locale, String key) =>
    _strings[locale]?[key] ?? _strings[AppLocale.en]?[key] ?? key;
