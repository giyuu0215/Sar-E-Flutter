import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bilingual localization — translates key UI labels.
/// Filipino is pure Filipino when selected; English is fully English.
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

/// Complete string table covering every screen in the app.
const Map<AppLocale, Map<String, String>> _strings =
    <AppLocale, Map<String, String>>{
  AppLocale.fil: <String, String>{
    // ── Bottom nav ──
    'tab_pos': 'POS',
    'tab_listahan': 'Listahan',
    'tab_inventory': 'Imbentaryo',
    'tab_analytics': 'Analytics',

    // ── App bar & headings ──
    'profile': 'Aking Profile',
    'settings': 'Mga Setting',
    'notifications': 'Mga Abiso',

    // ── POS / Scanner ──
    'scan_barcode': 'I-scan ang Barcode',
    'search_product': 'Hanapin ang produkto...',
    'cart_empty': 'Walang laman ang cart',
    'checkout': 'Magbayad',
    'add_to_cart': 'Idagdag sa Cart',
    'out_of_stock': 'Ubos na ang stock',
    'payment': 'Pagbabayad',
    'cash': 'Cash',
    'ewallet_qr': 'E-Wallet / QR',
    'total': 'Kabuuan',
    'change': 'Sukli',
    'qty_exceeds_stock':
        'Hindi sapat ang stock. Available: {available}, gusto: {requested}.',
    'cart_empty_checkout': 'Walang laman ang cart para sa checkout.',
    'cash_tendered': 'Cash na ibinayad (PHP)',
    'confirm_payment': 'Kumpimahin ang Bayad',
    'cancel_checkout': 'Kanselahin',
    'processing': 'Pinoproseso...',
    'checkout_success': 'Matagumpay ang transaksyon!',
    'checkout_failed': 'Hindi matagumpay ang checkout',
    'not_enough_stock': 'Hindi sapat ang stock',
    'stock_warning_body':
        'Ang "{product}" ay {available} na lang ang stock.\n\nMangyaring bawasan ang dami o dagdagan muna ang stock.',
    'remove_item': 'Alisin ang Item?',
    'remove_item_body':
        'Sigurado ka bang gusto mong alisin ang "{product}" sa cart?',
    'remove': 'Alisin',
    'invalid_quantity': 'Hindi Wastong Dami',
    'qty_negative': 'Hindi pwedeng negative ang dami.',
    'tap_to_scan': 'Pindutin para Mag-scan ng Barcode',
    'point_camera': 'Itutok ang camera sa barcode ng produkto',
    'or_search': 'o gamitin ang 🔍 Hanapin sa itaas',
    'scan': 'SCAN',
    'search_products': 'Hanapin ang produkto gamit ang pangalan o barcode...',
    'no_product_found': 'Walang nahanap na produkto para sa barcode',
    'added': 'Naidagdag',
    'share_pdf': 'I-save ang PDF',
    'done': 'Tapos Na',
    'scan_to_verify': 'I-scan para i-verify ang resibo',

    // ── Inventory ──
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
    'barcode': 'Barcode',
    'threshold': 'Threshold ng Mababang Stock',
    'product_added': 'Naidagdag ang produkto',
    'product_updated': 'Na-update ang produkto',
    'product_deleted': 'Natanggal ang produkto',
    'stock_updated': 'Na-update ang stock',
    'confirm_delete': 'Sigurado ka bang gusto mong tanggalin ang produktong ito?',
    'cost_exceeds_price':
        'Ang puhunan ay mas mataas sa presyo. Magiging lugi. Ituloy pa rin?',

    // ── Listahan (Credits) ──
    'new_credit': 'Bagong Utang',
    'customer': 'Customer',
    'amount': 'Halaga',
    'due_date': 'Deadline ng Bayad',
    'repay': 'Magbayad',
    'settled': 'Bayad Na',
    'overdue': 'Lampas na sa Deadline',
    'active': 'Aktibo',
    'outstanding': 'Natitirang Utang',
    'new_customer': 'Bagong Customer',
    'search_customer': 'Hanapin ang customer...',
    'items_hint': 'Mga items (comma separated)',
    'credit_entries': 'Mga Entry ng Utang',
    'record_payment': 'Mag-record ng Bayad',
    'no_credits': 'Walang naka-record na utang',
    'credit_added': 'Naidagdag ang entry ng utang',
    'payment_recorded': 'Na-record ang bayad',
    'select_customer': 'Pumili muna ng customer.',
    'enter_valid_amount': 'Maglagay ng wastong halaga.',
    'exceeds_balance': 'Ang halaga ay lumampas sa natitirang balanse.',

    // ── Analytics ──
    'revenue': 'Kita',
    'gross_profit': 'Gross na Kita',
    'cogs': 'COGS (Gastos sa Paninda)',
    'profit_margin': 'Margin',
    'transactions': 'Mga Transaksyon',
    'top_products': 'Mga Top na Produkto',
    'recent_transactions': 'Mga Kamakailang Transaksyon',
    'revenue_vs_cogs': 'Kita vs COGS',
    'view_all': 'Tingnan Lahat',
    'today': 'Ngayon',
    'this_week': 'Ngayong Linggo',
    'this_month': 'Ngayong Buwan',
    'export_pdf': 'I-export ang PDF',
    'pdf_saved': 'Na-save ang PDF',
    'pdf_error': 'Error sa PDF',
    'no_sales_yet': 'Wala pang naitala na transaksyon sa panahong ito',
    'transaction_detail': 'Detalye ng Transaksyon',
    'no_line_items': 'Walang nahanap na items',
    'refresh': 'I-refresh',
    'cogs_tooltip':
        'COGS = Gastos sa Paninda\nKabuuang puhunan ng lahat ng naibentang paninda.\nGross na Kita = Kita − COGS',

    // ── Settings ──
    'language': 'Wika',
    'notification_settings': 'Mga Setting ng Abiso',
    'low_stock_alerts': 'Alerto sa Mababang Stock',
    'overdue_alerts': 'Alerto sa Lampas na sa Deadline',
    'dark_mode': 'Dark Mode',
    'about': 'Tungkol sa Sar-E',
    'about_body':
        'Sar-E ay isang matalinong POS at pamamahala ng tindahan na app para sa Filipino sari-sari stores. Ginawa gamit ang Flutter at Firebase.',

    // ── Profile & Sync ──
    'change_pin': 'Palitan ang PIN',
    'add_cashier': 'Magdagdag ng Cashier',
    'logout': 'Mag-logout',
    'sign_out': 'Mag-sign Out',
    'store_name': 'Pangalan ng Tindahan',
    'payment_qr': 'Mga Payment QR Code',
    'sync_now': 'Mag-sync Ngayon',
    'force_sync': 'Puwersahang Full Sync',
    'online': 'Online',
    'offline': 'Offline',
    'pending_items': 'naka-pending na items',
    'syncing': 'Nag-sync...',
    'last_sync': 'Huling sync',
    'offline_notice':
        'Offline mode — ang data ay naka-save lang sa device na ito.',
    'sync_complete': 'Kumpleto na ang sync',
    'sync_failed': 'Hindi matagumpay ang sync',

    // ── Auth / Setup ──
    'welcome': 'Maligayang Pagdating sa Sar-E',
    'setup_subtitle': 'I-setup ang iyong point-of-sale sa ilang segundo.',
    'continue_google': 'Magpatuloy gamit ang Google',
    'continue_offline': 'Magpatuloy nang walang account',
    'google_backup_note':
        'Ang Google accounts ay nagbibigay ng cloud backup at multi-device sync.',
    'set_up_store': 'I-setup ang Iyong Tindahan',
    'google_linked': 'Naka-link na ang Google account. Ilagay ang detalye.',
    'offline_setup': 'Offline Setup',
    'offline_subtitle':
        'Ang iyong data ay mananatili sa device na ito (walang cloud sync).',
    'welcome_back': 'Welcome Back! 👋',
    'enter_pin': 'Ilagay ang iyong PIN para magpatuloy.',
    'reset_pin': 'I-reset ang PIN 🔒',
    'reset_pin_subtitle': 'Gumawa ng bagong PIN.',
    'forgot_pin': 'Nakalimutan ang PIN?',
    'pin_label': 'PIN (4+ na digit)',
    'confirm_pin': 'Kumpirmahin ang PIN',
    'store_name_label': 'Pangalan ng Tindahan',
    'pin_too_short': 'Kailangan ang PIN na 4 digit o higit pa.',
    'pins_mismatch': 'Hindi tugma ang mga PIN.',
    'enter_store_name': 'Mangyaring ilagay ang pangalan ng tindahan.',
    'setup_failed': 'Hindi matagumpay ang setup.',
    'invalid_pin': 'Hindi tama ang PIN. Subukan muli o pindutin ang Nakalimutan ang PIN.',

    // ── General ──
    'cancel': 'Kanselahin',
    'save': 'I-save',
    'confirm': 'Kumpirmahin',
    'add': 'Idagdag',
    'close': 'Isara',
    'ok': 'OK',
    'search': 'Hanapin',
    'no_data': 'Walang data',
    'loading': 'Naglo-load...',
    'error': 'May error',
    'success': 'Tagumpay',
    'warning': 'Babala',
    'required_field': 'Kinakailangan ang field na ito.',
    'invalid_amount': 'Maglagay ng wastong halaga.',
    'negative_not_allowed': 'Hindi pwedeng negative ang value.',
  },
  AppLocale.en: <String, String>{
    // ── Bottom nav ──
    'tab_pos': 'POS',
    'tab_listahan': 'Credits',
    'tab_inventory': 'Inventory',
    'tab_analytics': 'Analytics',

    // ── App bar & headings ──
    'profile': 'Profile',
    'settings': 'Settings',
    'notifications': 'Notifications',

    // ── POS / Scanner ──
    'scan_barcode': 'Scan Barcode',
    'search_product': 'Search product...',
    'cart_empty': 'Cart is empty',
    'checkout': 'Checkout',
    'add_to_cart': 'Add to Cart',
    'out_of_stock': 'Out of stock',
    'payment': 'Payment',
    'cash': 'Cash',
    'ewallet_qr': 'E-Wallet / QR',
    'total': 'Total',
    'change': 'Change',
    'qty_exceeds_stock':
        'Not enough stock. Available: {available}, requested: {requested}.',
    'cart_empty_checkout': 'Cart is empty for checkout.',
    'cash_tendered': 'Cash tendered (PHP)',
    'confirm_payment': 'Confirm Payment',
    'cancel_checkout': 'Cancel',
    'processing': 'Processing...',
    'checkout_success': 'Transaction successful!',
    'checkout_failed': 'Checkout failed',
    'not_enough_stock': 'Not enough stock',
    'stock_warning_body':
        '"{product}" only has {available} in stock.\n\nPlease adjust the quantity or restock first.',
    'remove_item': 'Remove Item?',
    'remove_item_body':
        'Are you sure you want to remove "{product}" from the cart?',
    'remove': 'Remove',
    'invalid_quantity': 'Invalid Quantity',
    'qty_negative': 'Quantity cannot be negative.',
    'tap_to_scan': 'Tap to Scan Barcode',
    'point_camera': 'Point camera at product barcode',
    'or_search': 'or use 🔍 Search above',
    'scan': 'SCAN',
    'search_products': 'Search product by name or barcode...',
    'no_product_found': 'No product found for barcode',
    'added': 'Added',
    'share_pdf': 'Save PDF',
    'done': 'Done',
    'scan_to_verify': 'Scan to verify receipt',

    // ── Inventory ──
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
    'barcode': 'Barcode',
    'threshold': 'Low Stock Threshold',
    'product_added': 'Product added',
    'product_updated': 'Product updated',
    'product_deleted': 'Product deleted',
    'stock_updated': 'Stock updated',
    'confirm_delete': 'Are you sure you want to delete this product?',
    'cost_exceeds_price':
        'Cost exceeds selling price. You will operate at a loss. Continue anyway?',

    // ── Listahan (Credits) ──
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
    'credit_added': 'Credit entry added',
    'payment_recorded': 'Payment recorded',
    'select_customer': 'Please select a customer.',
    'enter_valid_amount': 'Enter a valid amount.',
    'exceeds_balance': 'Amount exceeds outstanding balance.',

    // ── Analytics ──
    'revenue': 'Revenue',
    'gross_profit': 'Gross Profit',
    'cogs': 'COGS (Cost of Goods Sold)',
    'profit_margin': 'Margin',
    'transactions': 'Transactions',
    'top_products': 'Top Products',
    'recent_transactions': 'Recent Transactions',
    'revenue_vs_cogs': 'Revenue vs COGS',
    'view_all': 'View All',
    'today': 'Today',
    'this_week': 'This Week',
    'this_month': 'This Month',
    'export_pdf': 'Export PDF',
    'pdf_saved': 'PDF Saved',
    'pdf_error': 'PDF Error',
    'no_sales_yet': 'No completed sales yet in this period',
    'transaction_detail': 'Transaction Detail',
    'no_line_items': 'No line items found',
    'refresh': 'Refresh',
    'cogs_tooltip':
        'COGS = Cost of Goods Sold\nTotal cost price of all items sold.\nGross Profit = Revenue − COGS',

    // ── Settings ──
    'language': 'Language',
    'notification_settings': 'Notification Settings',
    'low_stock_alerts': 'Low Stock Alerts',
    'overdue_alerts': 'Overdue Alerts',
    'dark_mode': 'Dark Mode',
    'about': 'About Sar-E',
    'about_body':
        'Sar-E is a smart POS and store management app for Filipino sari-sari stores. Built with Flutter and Firebase.',

    // ── Profile & Sync ──
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
    'sync_complete': 'Sync complete',
    'sync_failed': 'Sync failed',

    // ── Auth / Setup ──
    'welcome': 'Welcome to Sar-E',
    'setup_subtitle': 'Set up your point-of-sale in seconds.',
    'continue_google': 'Continue with Google',
    'continue_offline': 'Continue without account',
    'google_backup_note':
        'Google accounts enable cloud backup & multi-device sync.',
    'set_up_store': 'Set Up Your Store',
    'google_linked': 'Google account linked. Enter your store details.',
    'offline_setup': 'Offline Setup',
    'offline_subtitle':
        'Your data stays on this device only (no cloud sync).',
    'welcome_back': 'Welcome Back! 👋',
    'enter_pin': 'Enter your PIN to continue.',
    'reset_pin': 'Reset Your PIN 🔒',
    'reset_pin_subtitle': 'Create a new PIN.',
    'forgot_pin': 'Forgot PIN?',
    'pin_label': 'PIN (4+ digits)',
    'confirm_pin': 'Confirm PIN',
    'store_name_label': 'Store Name',
    'pin_too_short': 'PIN must be at least 4 digits.',
    'pins_mismatch': 'PINs do not match.',
    'enter_store_name': 'Please enter your store name.',
    'setup_failed': 'Setup failed.',
    'invalid_pin': 'Invalid PIN. Try again or tap Forgot PIN.',

    // ── General ──
    'cancel': 'Cancel',
    'save': 'Save',
    'confirm': 'Confirm',
    'add': 'Add',
    'close': 'Close',
    'ok': 'OK',
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
