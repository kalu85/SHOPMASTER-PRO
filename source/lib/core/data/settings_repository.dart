import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';

/// Shop profile and app preferences (one row per setting).
class ShopSettings {
  const ShopSettings({
    this.shopName = 'My Shop',
    this.address = '',
    this.phone = '',
    this.gstin = '',
    this.gstRegistrationType = 'not_registered',
    this.gstReturnFrequency = 'monthly',
    this.bankName = '',
    this.accountNo = '',
    this.ifsc = '',
    this.upiId = '',
    this.footer = 'Thank you for your business!',
    this.logoPath = '',
    this.invoicePrefix = 'INV',
    this.defaultGst = true,
    this.defaultPayMode = 'Cash',
    this.autoBackup = true,
    this.lastBackup = '',
  });

  final String shopName;
  final String address;
  final String phone;
  final String gstin;
  /// User-selected profile only; this does not verify GST registration.
  final String gstRegistrationType;
  /// Preparation preference; actual due dates/eligibility come from GST Portal.
  final String gstReturnFrequency;
  final String bankName;
  final String accountNo;
  final String ifsc;
  final String upiId;
  final String footer;
  final String logoPath;
  final String invoicePrefix;
  final bool defaultGst;
  final String defaultPayMode;
  final bool autoBackup;
  final String lastBackup;

  ShopSettings copyWith({
    String? shopName,
    String? address,
    String? phone,
    String? gstin,
    String? gstRegistrationType,
    String? gstReturnFrequency,
    String? bankName,
    String? accountNo,
    String? ifsc,
    String? upiId,
    String? footer,
    String? logoPath,
    String? invoicePrefix,
    bool? defaultGst,
    String? defaultPayMode,
    bool? autoBackup,
    String? lastBackup,
  }) =>
      ShopSettings(
        shopName: shopName ?? this.shopName,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        gstin: gstin ?? this.gstin,
        gstRegistrationType: gstRegistrationType ?? this.gstRegistrationType,
        gstReturnFrequency: gstReturnFrequency ?? this.gstReturnFrequency,
        bankName: bankName ?? this.bankName,
        accountNo: accountNo ?? this.accountNo,
        ifsc: ifsc ?? this.ifsc,
        upiId: upiId ?? this.upiId,
        footer: footer ?? this.footer,
        logoPath: logoPath ?? this.logoPath,
        invoicePrefix: invoicePrefix ?? this.invoicePrefix,
        defaultGst: defaultGst ?? this.defaultGst,
        defaultPayMode: defaultPayMode ?? this.defaultPayMode,
        autoBackup: autoBackup ?? this.autoBackup,
        lastBackup: lastBackup ?? this.lastBackup,
      );

  Map<String, String> toMap() => {
        'shop_name': shopName,
        'address': address,
        'phone': phone,
        'gstin': gstin,
        'gst_registration_type': gstRegistrationType,
        'gst_return_frequency': gstReturnFrequency,
        'bank_name': bankName,
        'account_no': accountNo,
        'ifsc': ifsc,
        'upi_id': upiId,
        'footer': footer,
        'logo_path': logoPath,
        'invoice_prefix': invoicePrefix,
        'default_gst': defaultGst ? '1' : '0',
        'default_pay_mode': defaultPayMode,
        'auto_backup': autoBackup ? '1' : '0',
        'last_backup': lastBackup,
      };

  factory ShopSettings.fromMap(Map<String, String> m) {
    const d = ShopSettings();
    return ShopSettings(
      shopName: m['shop_name'] ?? d.shopName,
      address: m['address'] ?? d.address,
      phone: m['phone'] ?? d.phone,
      gstin: m['gstin'] ?? d.gstin,
      gstRegistrationType: m['gst_registration_type'] ?? d.gstRegistrationType,
      gstReturnFrequency: m['gst_return_frequency'] ?? d.gstReturnFrequency,
      bankName: m['bank_name'] ?? d.bankName,
      accountNo: m['account_no'] ?? d.accountNo,
      ifsc: m['ifsc'] ?? d.ifsc,
      upiId: m['upi_id'] ?? d.upiId,
      footer: m['footer'] ?? d.footer,
      logoPath: m['logo_path'] ?? d.logoPath,
      invoicePrefix: m['invoice_prefix'] ?? d.invoicePrefix,
      defaultGst: (m['default_gst'] ?? '1') == '1',
      defaultPayMode: m['default_pay_mode'] ?? d.defaultPayMode,
      autoBackup: (m['auto_backup'] ?? '1') == '1',
      lastBackup: m['last_backup'] ?? d.lastBackup,
    );
  }
}

class SettingsRepository {
  SettingsRepository._();
  static final SettingsRepository instance = SettingsRepository._();

  Future<Database> get _db => AppDatabase.instance.db;

  Future<ShopSettings> load() async {
    final db = await _db;
    final rows = await db.query('settings');
    return ShopSettings.fromMap({
      for (final r in rows) r['key'] as String: r['value'] as String,
    });
  }

  Future<void> save(ShopSettings s) async {
    final db = await _db;
    final batch = db.batch();
    s.toMap().forEach((k, v) {
      batch.insert(
        'settings',
        {'key': k, 'value': v},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await batch.commit(noResult: true);
  }

  Future<void> setValue(String key, String value) async {
    final db = await _db;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
