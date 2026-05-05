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
    'qty_exceeds_stock':
        'Hindi sapat ang stock. Available: {available}, gusto: {requested}.',
    'cart_empty_checkout': 'Walang laman ang cart para sa checkout.',

    // Inventory
    'inventory': 'Imbentaryo',
    'add_product': 'Magdagdag ng Produkto',
    'add_stock': 'Dagdagan ng Stock',
    'edit': 'I-edit',
    'delete': 'Tanggalin',
    'product_name': 'Pangalan ng Produkto',
    'price': 'Presyo',
    'cost': 'Halaga ng Puhunan',
    'stock': 'Stock',
    'category': 'Kategorya',
    'all_items': 'Lahat',
    'low_stock': 'Mababang Stock',
    'products': 'Mga Produkto',
    'total_value': 'Kabuuang Halaga',
    'add_category': 'Magdagdag ng Kategorya',

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
    'new_customer': 'Bagong Customer',
    'search_customer': 'Hanapin ang customer...',
    'items_hint': 'Mga items (comma separated)',
    'credit_entries': 'Mga Entry ng Utang',
    'record_payment': 'Mag-record ng Bayad',
    'no_credits': 'Walang naka-record na utang',

    // Analytics
    'revenue': 'Kita',
    'gross_profit': 'Gross Profit',
    'profit_margin': 'Margin',
    'transactions': 'Transaksyon',
    'top_products': 'Mga Top na Produkto',
    'recent_transactions': 'Mga Kamakailang Transaksyon',
    'revenue_vs_cogs': 'Kita vs COGS',
    'view_all': 'Tingnan Lahat',
    'today': 'Ngayon',
    'this_week': 'Ngayong Linggo',
    'this_month': 'Ngayong Buwan',

    // Settings
    'language': 'Wika',
    'notification_settings': 'Mga Setting ng Abiso',
    'low_stock_alerts': 'Alerto sa Mababang Stock',
    'overdue_alerts': 'Alerto sa Overdue',
    'dark_mode': 'Dark Mode',
    'about': 'Tungkol sa Sar-E',

    // Profile & Sync
    'change_pin': 'Palitan ang PIN',
    'add_cashier': 'Magdagdag ng Cashier',
    'logout': 'Mag-logout',
    'sign_out': 'Mag-sign Out',
    'store_name': 'Pangalan ng Tindahan',
    'payment_qr': 'Payment QR Codes',
    'sync_now': 'Mag-sync Ngayon',
    'force_sync': 'Force Full Sync',
    'online': 'Online',
    'offline': 'Offline',
    'pending_items': 'pending na items',
    'syncing': 'Nag-sync...',
    'last_sync': 'Huling sync',
    'offline_notice': 'Offline mode — ang data ay naka-save lang sa device na ito.',

    // General
    'cancel': 'Cancel',
    'save': 'Save',
    'confirm': 'Confirm',
    'add': 'Add',
    'remove': 'Remove',
    'search': 'Hanapin',
    'no_data': 'Walang data',
    'loading': 'Loading...',
    'error': 'May error',
    'success': 'Tagumpay',
    'warning': 'Babala',
    'required_field': 'Kinakailangan ang field na ito.',
    'invalid_amount': 'Maglagay ng wastong halaga.',
    'negative_not_allowed': 'Hindi pwedeng negative ang value.',
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
    'qty_exceeds_stock':
        'Not enough stock. Available: {available}, requested: {requested}.',
    'cart_empty_checkout': 'Cart is empty for checkout.',
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
    'products': 'Products',
    'total_value': 'Total Value',
    'add_category': 'Add Category',
    'new_credit': 'New Credit',
    'customer': 'Customer',
    'amount': 'Amount',
    'due_date': 'Due Date',
    'repay': 'Repay',
    'settled': 'Settled',
    'overdue': 'Overdue',
    'active': 'Active',
    'outstanding': 'Outstanding',
    'new_customer': 'New Customer',
    'search_customer': 'Search customer...',
    'items_hint': 'Items (comma separated)',
    'credit_entries': 'Credit Entries',
    'record_payment': 'Record Payment',
    'no_credits': 'No credit entries recorded',
    'revenue': 'Revenue',
    'gross_profit': 'Gross Profit',
    'profit_margin': 'Margin',
    'transactions': 'Transactions',
    'top_products': 'Top Products',
    'recent_transactions': 'Recent Transactions',
    'revenue_vs_cogs': 'Revenue vs COGS',
    'view_all': 'View All',
    'today': 'Today',
    'this_week': 'This Week',
    'this_month': 'This Month',
    'language': 'Language',
    'notification_settings': 'Notification Settings',
    'low_stock_alerts': 'Low Stock Alerts',
    'overdue_alerts': 'Overdue Alerts',
    'dark_mode': 'Dark Mode',
    'about': 'About Sar-E',
    'change_pin': 'Change PIN',
    'add_cashier': 'Add Cashier',
    'logout': 'Logout',
    'sign_out': 'Sign Out',
    'store_name': 'Store Name',
    'payment_qr': 'Payment QR Codes',
    'sync_now': 'Sync Now',
    'force_sync': 'Force Full Sync',
    'online': 'Online',
    'offline': 'Offline',
    'pending_items': 'pending items',
    'syncing': 'Syncing...',
    'last_sync': 'Last sync',
    'offline_notice': 'Offline mode — data is stored on this device only.',
    'cancel': 'Cancel',
    'save': 'Save',
    'confirm': 'Confirm',
    'add': 'Add',
    'remove': 'Remove',
    'search': 'Search',
    'no_data': 'No data',
    'loading': 'Loading...',
    'error': 'Error',
    'success': 'Success',
    'warning': 'Warning',
    'required_field': 'This field is required.',
    'invalid_amount': 'Enter a valid amount.',
    'negative_not_allowed': 'Value cannot be negative.',
  },
};

/// Convenience function to get localized string
String t(AppLocale locale, String key) =>
    _strings[locale]?[key] ?? _strings[AppLocale.en]?[key] ?? key;
